// src/index.js
import express, { Express, Request, Response } from "express";
import multer, { Multer } from "multer";
import dotenv from "dotenv";
import { OpenSheetMusicDisplay, MXLHelper } from "opensheetmusicdisplay";
import jsdom from "jsdom";
import fs from "node:fs/promises";
import cors from "cors";
import { body, validationResult } from "express-validator";
import headless_gl from "gl";
// @ts-ignore
import zip from "express-easy-zip";

dotenv.config();

const app: Express = express();
const upload: Multer = multer({ dest: "musicxml_uploads" });
const port = process.env.PORT;

app.use(cors());
app.use(zip());

app.post(
  "/musicxml-to-svg",
  upload.single("musicxml"),
  [body('pageWidth').isFloat({ gt: 0 }), body('pageHeight').optional().isFloat({ min: 0 })],
  async (req: Request, res: Response) => {
    const result = validationResult(req);

    if (!result.isEmpty()) {
      return res.status(400).send("Invalid width or height");
    }

    const { pageWidth, pageHeight } = req.body;

    const width = Number.parseInt(pageWidth, 10) || 0;
    let height = Number.parseInt(pageHeight, 10) || 0;

    let pageFormat = "Endless";
    if (height == 0) {
      height = 32767;
    } else {
      pageFormat = `${width}x${height}`;
    }

    const uploadedFile = req.file;
    if (uploadedFile) {
      const dom = new jsdom.JSDOM("<!DOCTYPE html></html>");

      // @ts-ignore
      global.window = dom.window;
      global.document = window.document;
      global.HTMLElement = window.HTMLElement;
      global.HTMLAnchorElement = window.HTMLAnchorElement;
      global.XMLHttpRequest = window.XMLHttpRequest;
      global.DOMParser = window.DOMParser;
      global.Node = window.Node;

      const oldCreateElement = document.createElement.bind(document);
      const newCreateElement = (tagName: Parameters<typeof document.createElement>[0], options: ElementCreationOptions) => {
        if (tagName.toLowerCase() === "canvas") {
          const canvas = oldCreateElement("canvas", options);
          const oldGetContext = canvas.getContext.bind(canvas);
          // @ts-ignore
          canvas.getContext = function (contextType, contextAttributes) {
            if (
              contextType.toLowerCase() === "webgl" ||
              contextType.toLowerCase() === "experimental-webgl"
            ) {
              const gl = headless_gl(
                canvas.width,
                canvas.height,
                contextAttributes
              );
              //@ts-ignore
              gl.canvas = canvas;
              return gl;
            } else {
              return oldGetContext(contextType, contextAttributes);
            }
          };

          return canvas;
        } else {
          return oldCreateElement(tagName, options);
        }
      };
      document.createElement = newCreateElement;

      const div = document.createElement("div");
      div.id = "browserlessDiv";
      document.body.appendChild(div);

      div.setAttribute("width", width.toString());
      div.setAttribute("height", height.toString());
      div.setAttribute("offsetWidth", width.toString());

      Object.defineProperties(window.HTMLElement.prototype, {
        offsetLeft: {
          get: function () {
            return parseFloat(window.getComputedStyle(this).marginTop) || 0;
          },
        },
        offsetTop: {
          get: function () {
            return parseFloat(window.getComputedStyle(this).marginTop) || 0;
          },
        },
        offsetHeight: {
          get: function () {
            return height;
          },
        },
        offsetWidth: {
          get: function () {
            return width;
          },
        },
      });

      const osmd = new OpenSheetMusicDisplay(div, {
        autoResize: false,
        backend: "svg",
        pageBackgroundColor: "#FFFFFF",
        pageFormat,
      });

      const uploadedPath = uploadedFile.path;
      const musicXMLFile = await fs.readFile(uploadedPath);

      let musicXMLString;
      if (uploadedFile.originalname.endsWith(".mxl")) {
        // @ts-ignore
        musicXMLString = await MXLHelper.MXLtoXMLstring(musicXMLFile);
      } else {
        musicXMLString = musicXMLFile
          .toString()
          .replace(/[^\x20-\x7E]/g, "")
          .trim();
      }

      await fs.unlink(uploadedPath);

      await osmd.load(musicXMLString);
      osmd.render();

      let markupStrings = [];

      for (let pageNumber = 1, svgElement; svgElement = document.getElementById("osmdSvgPage" + pageNumber); pageNumber++) {
        // The important xmlns attribute is not serialized unless we set it here
        svgElement.setAttribute("xmlns", "http://www.w3.org/2000/svg");
        markupStrings.push(svgElement.outerHTML);
      }

      const fileNames = markupStrings.map((_, idx) => {
        const filePath = `musicxml_uploads/music_${idx}.svg`;
        const name = `music_${idx}.svg`;

        return { path: filePath, name };
      });

      const writeToFiles = markupStrings.map((string, idx) => fs.writeFile(fileNames[idx].path, string));
      await Promise.all(writeToFiles);
      
      // @ts-ignore
      await res.zip({
        files: fileNames,
        filename: 'music-xml-to-svgs.zip'
      });

      await Promise.all(fileNames.map(({ path }) => fs.unlink(path)));
    } else {
      res.status(400).send("No file uploaded");
    }
  }
);

app.listen(port, () => {
  console.log(`[server]: Server is running at http://localhost:${port}`);
});
