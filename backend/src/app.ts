import express from "express";
import helmet from "helmet";
import cors from "cors";
import { notFound } from "./middleware/notFound.js";
import { errorHandler } from "./middleware/errorHandler.js";
import { pool } from "./db/pool.js";
import { env } from "./config/env.js";

export const app = express();

app.use(helmet());
app.use(cors({ origin: env.CORS_ORIGIN }));
app.use(express.json({ limit: "100kb" }));

app.get("/api/v1/health", async (req, res) => {
	try {
		await pool.query("SELECT 1");
		res.json({ success: true, data: { status: "ok", db: "up" } });
	} catch (error) {
		console.error("Health check failed:", error);
		res.status(503).json({
			success: false,
			error: { code: "DB_UNAVAILABLE", message: "Baza trenutno nije dostupna." },
		});
	}
});

app.use(notFound);
app.use(errorHandler);
