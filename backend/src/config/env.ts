import {z} from "zod";
import "dotenv/config";

const envSchema = z.object({
    PORT:z.coerce.number().default(3000),
    CORS_ORIGIN: z.url(),
    DB_HOST: z.string().min(1),
    DB_PORT: z.coerce.number(),
    DB_USER: z.string().min(1),
    DB_PASSWORD: z.string(),
    DB_NAME: z.string().min(1)
})

const parsed = envSchema.safeParse(process.env);

if(!parsed.success) {
    console.error("Invalid environment variables:", z.treeifyError(parsed.error));
    process.exit(1);
}
export const env = parsed.data;