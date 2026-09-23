import { copyFile, access } from "node:fs/promises";
// Keep the website copy aligned with the iPhone source in a full repo checkout.
// Standalone Vercel CLI uploads use the reviewed copy included with the website.
const source = new URL(
  "../../ios/OpenAdapt/Resources/PrivacyPolicy.txt",
  import.meta.url,
);
const target = new URL("../src/content/app-privacy.txt", import.meta.url);
try {
  await access(source);
} catch {
  process.exit(0);
}
await copyFile(source, target);
