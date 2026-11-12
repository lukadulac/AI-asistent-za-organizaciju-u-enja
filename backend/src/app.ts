import express from "express";
import helmet from "helmet";
import cors from "cors";
import {notFound} from "./middleware/notFound.js";
import {errorHandler} from "./middleware/errorHandler.js";

export const app = express();

app.use(helmet());
app.use(cors({ origin: "http://localhost:5173" }));
app.use(express.json({ limit: "100kb" }));

app.get("/api/v1/health", (req, res) => {
  res.json({ success: true, data: { status: "ok" } });
});

app.use(notFound);
app.use(errorHandler);