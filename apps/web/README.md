# OpenAdapt website

A static Astro site for openadapt.app. Native client source remains outside this app. The build uploads only this directory to Vercel.

## Local development

```sh
cd apps/web
npm ci
npm run dev
npm run check
npm run build
```

## Launch switches

Edit `src/site.ts` and redeploy:

- `repo` and `branch`: source, star, clone, and contribution links are enabled for the owner's requested open-source launch presentation. The repository was still private when this presentation was prepared; publishing the website does not change GitHub visibility or make these links accessible to anonymous visitors. Repository publication remains a separate owner action.
- `testflight`: set to the real approved public invitation URL. An empty value renders “coming soon” and links to the release status.
- `appStore`: set to the actual Apple listing after release.
- Marketplace URLs in `src/shoes.ts`: replace only with real product or approved affiliate links. Set the matching `affiliate` field to `true` when the URL earns commission. The site then renders a nearby disclosure and marks that link `rel="sponsored"`.

Compatibility copy reflects the repository's September 22, 2026 documentation: Auto Max 2.4.3M is the verified profile; new enrollment/calibration and broader iPhone hardware validation are pending. Update the FAQ, compatibility note, and client copy when new hardware evidence or release status changes. Client ideas are not advertised as implemented features.

## Deploy

Vercel project: `openadapt` in `gianlus-projects`. The Git integration builds `apps/web` from the monorepo. Automatic production deployments use `master` once the website PR is merged. Run manual deployments from the repository root so Vercel can resolve that root directory.

```sh
# From the repository root:
npx vercel link --project openadapt --scope gianlus-projects
npx vercel --prod --scope gianlus-projects
```

Use the DNS records Vercel reports for this project when connecting `openadapt.app`. Do not replace unrelated Cloudflare mail, verification, or other subdomain records. The apex is configured in Cloudflare as a DNS-only CNAME to `0d226bda3b0ff7f4.vercel-dns-017.com`. Vercel reports valid configuration. A `www` redirect is optional and separate.

## Referral program

eBay shopping links use the owner's active eBay Partner Network campaign, with one shoe-specific Custom ID per model. Each points to relevant search results so visitors can choose their size, condition, and seller. Links use eBay's documented tracking URL format, are marked `rel="sponsored"`, and have a commission disclosure near the gallery. The website adds no tracking script or visitor identifier. Commission eligibility depends on eBay's qualifying purchase terms.

StockX documents an affiliate program through Impact. Keep its links ordinary until enrollment and tracking details are available. No official GOAT sneaker affiliate program was verified, so GOAT is absent from the shopping options. Photo-source credits remain because the gallery uses GOAT product photography.

Sources:
- https://stockx.com/news/en-us/affiliate-faq/
- https://stockx.com/news/en-us/stockx-affiliate-program/
- https://partnernetwork.ebay.com/our-program
- https://partnernetwork.ebay.com/our-program/rate-card
- https://partnernetwork.ebay.com/resources/create-your-affiliate-link
- https://www.developer.ebay.com/api-docs/buy/static/ref-epn-link.html
- https://partnernetwork.ebay.com/solutions/optimizing-using-tracking-parameters

## Assets and privacy

- The sneaker mark is the project's original MIT-licensed artwork from `assets/brand/sneaker.svg`.
- The iPhone screenshot is the project’s own labeled Simulator demo capture. The Omarchy view is a labeled HTML/CSS theme preview matching the native panel’s controls, using the official Tokyo Night palette: https://raw.githubusercontent.com/basecamp/omarchy/master/themes/tokyo-night/colors.toml
- Omarchy’s logo and wordmark come from https://omarchy.org/brand/ and retain their default brand green. These third-party brand assets are not covered by the OpenAdapt MIT license.
- Product photos come from the matching GOAT listing recorded in each model’s `photoSource` field in `src/shoes.ts`. Auto Max: https://www.goat.com/sneakers/adapt-auto-max-triple-black-cz6799-002 . Third-party product photography is not covered by this repository's MIT license. Replace with owner photography or approved affiliate creative when available.
- Inter and Inter Tight are self-hosted, with their font licenses in `public/fonts/`.
- No analytics scripts, email collection, cloud app backend, Bluetooth access, or cookies are added by the website. The interactive demo is browser-local simulation.
- Search metadata, a social preview, sitemap, robots file, security headers, privacy page, and a 404 page are included.

## Shared iPhone privacy policy

`npm run build` refreshes `src/content/app-privacy.txt` from the iPhone policy when building from the full repository. Standalone website uploads use the checked-in copy. The `/app-privacy` route keeps the app policy separate from website privacy.

## Shoe gallery

The five models mirror the native app catalog, not five verified profiles. Only Auto Max firmware 2.4.3M is marked verified. Use `src/shoes.ts` to update model evidence and per-link affiliate flags. The carousel is server-rendered, uses native scroll snap and touch scrolling, has keyboard/thumbnail/previous/next controls, and never advances automatically. Reduced Motion disables smooth scrolling. Without JavaScript, all cards and model anchor links remain accessible.

Photo sources (GOAT, retrieved September 23, 2026):
- Adapt BB: https://image.goat.com/transform/v1/attachments/product_template_additional_pictures/images/079/299/458/original/487879_01.jpg.jpeg
- Adapt BB 2.0: https://image.goat.com/transform/v1/attachments/product_template_additional_pictures/images/080/337/367/original/589235_01.jpg.jpeg
- Adapt Huarache: https://image.goat.com/transform/v1/attachments/product_template_additional_pictures/images/079/333/407/original/546697_01.jpg.jpeg
- Air Jordan 11 Adapt: https://image.goat.com/transform/v1/attachments/product_template_additional_pictures/images/100/071/868/original/704154_01.jpg.jpeg

### Affiliate status — September 23, 2026

The owner completed eBay sign-in and its Partner Network dashboard shows campaign `5339213069` (`default`) as Active. All five shoe links use that campaign and `openadapt-<shoe-id>` Custom IDs. The campaign ID is intentionally public in referral URLs; it is not an API credential. Link format and disclosure were checked, but attributed sales and payouts have not been verified.

Impact's marketplace application shows **In Review**. StockX affiliate approval and tracking links have not been verified. The homepage contains the owner's Impact site-verification meta tag.

StockX’s current offer shows 3% on qualifying sneaker sales to new customers, 1% to existing customers, and 15-day last-click attribution. Section 2.2 restricts links near competing marketplaces and use of creative assets. Before activating StockX tracking, use separate StockX shopping pages without competitor links, or obtain an explicit exception. Update the disclosure to identify every affiliate marketplace when adding another program.

Application description: OpenAdapt is an independent software project working to restore app control to Nike Adapt shoes. Its website presents the iPhone and Omarchy clients, documents compatibility limits, and introduces the five-model Adapt family. Marketplace links help visitors find relevant resale listings. Promotion is through editorial content on https://openadapt.app; no paid advertising, coupon distribution, or incentivized traffic is planned. Do not invent audience or traffic metrics for application forms.
