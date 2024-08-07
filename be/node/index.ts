// src/index.js
import express, { Express, Request, Response } from "express";
import multer, { Multer } from "multer";
import dotenv from "dotenv";
import { OpenSheetMusicDisplay, MXLHelper } from "opensheetmusicdisplay";
import jsdom from "jsdom";
import cors from "cors";
import { body, validationResult } from "express-validator";
import compression from "compression";
import { constants } from "node:zlib";

/**
  * Uses canvas.measureText to compute and return the width of the given text of given font in pixels.
  * 
  * @param {string} text The text to be rendered.
  * @param {string} font The css font descriptor that text is to be rendered with (e.g. "bold 14px verdana").
  * 
  * @see https://stackoverflow.com/questions/118241/calculate-text-width-with-javascript/21015393#21015393
  */
function getTextWidth(text: string, font: string) {
  // re-use canvas object for better performance
  const canvas = document.createElement("canvas");
  const context = canvas.getContext("2d");
  if (!context) throw new Error("No 2d context");
  context.font = font;
  const metrics = context.measureText(text);
  return metrics.width;
}

dotenv.config();

const MIN_PAGE_WIDTH = 600;

const app: Express = express();
const upload: Multer = multer({ storage: multer.memoryStorage() });
const port = process.env.NODE_PORT;

app.use(cors());
app.use(compression({ level: constants.Z_BEST_COMPRESSION }));

app.post(
  "/musicxml-to-svg",
  upload.single("musicxml"),
  [body("pageWidth").isInt({ min: MIN_PAGE_WIDTH - 1 })],
  async (req: Request, res: Response) => {
    const result = validationResult(req);
    const uploadedFile = req.file;

    if (!result.isEmpty()) {
      return res.status(400).send("Invalid width or height");
    }
    if (!uploadedFile) {
      return res.status(400).send("No file uploaded");
    }

    const pageWidth = Number.parseInt(req.body.pageWidth, 10);

    const dom = new jsdom.JSDOM("<!DOCTYPE html></html>");
    // @ts-ignore
    global.window = dom.window;
    global.document = window.document;
    global.DOMParser = window.DOMParser;
    global.Node = window.Node;

    const container = Object.defineProperties(document.createElement("div"), {
      offsetWidth: {
        get: () => pageWidth,
      },
    });

    const oldCreateElementNS = document.createElementNS.bind(document);
    document.createElementNS = ((namespaceURI: string, qualifiedName: string) => {
      if (namespaceURI === "http://www.w3.org/2000/svg" && qualifiedName === "text") {
        const originalTextElem = oldCreateElementNS(namespaceURI, qualifiedName);

        return Object.defineProperties(originalTextElem, {
          getBBox: {
            value: () => {
              const width = getTextWidth(originalTextElem.textContent ?? "", "13pt Times New Roman");
              return {
                x: 0,
                y: 0,
                width,
                height: 0,
              };
            }
          }
        });
      } else {
        return oldCreateElementNS(namespaceURI, qualifiedName);
      }
    }) as typeof document.createElementNS;

    const osmd = new OpenSheetMusicDisplay(container, {
      autoResize: false,
      backend: "svg",
      pageBackgroundColor: "#FFFFFF",
    });

    const musicXMLFile = uploadedFile.buffer;

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

    await osmd.load(musicXMLString);
    osmd.render();

    // Because we're in OSMD endless mode, there should be only 1 SVG
    const svg = container.querySelector("svg")!;
    svg.setAttribute("xmlns", "http://www.w3.org/2000/svg");
    svg.removeAttribute("id");
    const svgElement = svg.outerHTML;

    res.send(svgElement);
    res.flush();
  }
);

app.listen(port, () => {
  console.log(`[server]: Server is running at http://localhost:${port}`);
});
