// src/index.js
import express, { Express, Request, Response } from "express";
import multer, { Multer } from "multer";
import dotenv from "dotenv";
import { OpenSheetMusicDisplay, MXLHelper } from "opensheetmusicdisplay";
import jsdom from "jsdom";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import cors from "cors";
import { body, validationResult } from "express-validator";
// @ts-ignore
import zip from "express-easy-zip";

dotenv.config();

const MIN_PAGE_WIDTH = 600;

const app: Express = express();
const upload: Multer = multer({ storage: multer.memoryStorage() });
const port = process.env.NODE_PORT;

app.use(cors());
app.use(zip());

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

    const svgElements = [...container.querySelectorAll("svg")].map((svg) => {
      svg.setAttribute("xmlns", "http://www.w3.org/2000/svg");
      return svg.outerHTML;
    });

    const tmpdir = os.tmpdir();
    const fileNames = svgElements.map((_, idx) => {
      const name = `music_${idx}.svg`;
      const filePath = path.join(tmpdir, name);
      return { path: filePath, name };
    });

    const writeToFiles = svgElements.map((svg, idx) => {
      return fs.writeFile(fileNames[idx].path, svg);
    });
    await Promise.all(writeToFiles);

    // @ts-ignore
    await res.zip({
      files: fileNames,
      filename: "music-xml-to-svgs.zip",
    });

    await Promise.all(fileNames.map(({ path }) => fs.unlink(path)));
  }
);

app.listen(port, () => {
  console.log(`[server]: Server is running at http://localhost:${port}`);
});
