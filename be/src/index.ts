// src/index.js
import express, { Express, Request, Response } from "express";
import multer, { Multer } from "multer";
import dotenv from "dotenv";
import { OpenSheetMusicDisplay, MXLHelper } from "opensheetmusicdisplay";
import jsdom from "jsdom";
import fs from "node:fs/promises";
import cors from "cors";

dotenv.config();

const app: Express = express();
const upload: Multer = multer({ dest: "musicxml_uploads" });
const port = process.env.PORT;

app.use(cors());

app.use(express.static('musicxml_uploads'));

app.post(
  "/musicxml-to-svg",
  upload.single("musicxml"),
  async (req: Request, res: Response) => {
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
      // @ts-ignore
      global.Canvas = window.Canvas;
      global.Blob = Blob;

      const { default: headless_gl } = await import("gl");
      const oldCreateElement = document.createElement.bind(document);
      // @ts-ignore
      document.createElement = function (tagName, options) {
        if (tagName.toLowerCase() === "canvas") {
          const canvas = oldCreateElement(tagName, options);
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

      const div = document.createElement("div");
      div.id = "browserlessDiv";
      document.body.appendChild(div);

      const width = 1440;
      const height = 32767;

      //@ts-ignore
      div.width = width;
      //@ts-ignore
      div.height = height;
      div.setAttribute("width", width.toString());
      div.setAttribute("height", height.toString());
      div.setAttribute("offsetWidth", width.toString());

      // hack: set offsetWidth reliably
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
        pageFormat: "Endless",
      });

      const path = uploadedFile.path;
      const musicXMLFile = await fs.readFile(path)
      const musicXMLString = musicXMLFile
        .toString()
        .replace(/[^\x20-\x7E]/g, "")
        .trim();
      
      await osmd.load(musicXMLString);
      osmd.render();

      let markupStrings = [];

      for (let pageNumber = 1; pageNumber < Number.POSITIVE_INFINITY; pageNumber++) {
        const svgElement = document.getElementById("osmdSvgPage" + pageNumber);
        if (!svgElement) {
          break;
        }
        
        // The important xmlns attribute is not serialized unless we set it here
        svgElement.setAttribute("xmlns", "http://www.w3.org/2000/svg");
        markupStrings.push(svgElement.outerHTML);
      }

      await fs.writeFile("musicxml_uploads/music.svg", markupStrings.join(""));
      await fs.unlink(path);
      res.status(200).send({ path: "music.svg" });
    } else {
      res.status(400).send("No file uploaded");
    }
  }
);

app.listen(port, () => {
  console.log(`[server]: Server is running at http://localhost:${port}`);
});
