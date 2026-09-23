export interface MarketplaceLink {
  name: string;
  url: string;
  affiliate: boolean;
}

// Active campaign verified in the owner's eBay Partner Network dashboard.
const ebayCampaignId = "5339213069";

function stockxSearchUrl(shoe: { brand: string; model: string }) {
  const url = new URL("https://stockx.com/search");
  url.searchParams.set("s", `${shoe.brand} ${shoe.model}`);
  return url.toString();
}

function ebayAffiliateUrl(shoe: { id: string; brand: string; model: string }) {
  // https://www.developer.ebay.com/api-docs/buy/static/ref-epn-link.html
  const url = new URL("https://www.ebay.com/sch/i.html");
  url.search = new URLSearchParams({
    _nkw: `${shoe.brand} ${shoe.model}`,
    mkevt: "1",
    mkcid: "1",
    mkrid: "711-53200-19255-0",
    campid: ebayCampaignId,
    toolid: "10001",
    customid: `openadapt-${shoe.id}`,
  }).toString();
  return url.toString();
}

// Catalog membership is not hardware verification. Keep evidence explicit per model.
const models = [
  {
    id: "auto-max",
    brand: "Nike Adapt",
    model: "Auto Max",
    year: "2020",
    colorway: "Triple Black",
    image: "/images/auto-max.jpg",
    width: 1614,
    height: 937,
    verified: true,
    description:
      "Air Max attitude. A fit all its own. The everyday silhouette at the heart of OpenAdapt’s development.",
    status: "Verified · firmware 2.4.3M",
    detail:
      "Control verified on the development pair. Fresh setup and fit calibration are still being tested.",
    photoSource:
      "https://www.goat.com/sneakers/adapt-auto-max-triple-black-cz6799-002",
  },
  {
    id: "adapt-bb",
    brand: "Nike Adapt",
    model: "BB",
    year: "2019",
    colorway: "Black",
    image: "/images/adapt-bb.jpg",
    width: 1250,
    height: 702,
    verified: false,
    description:
      "Where Adapt met the court. A sculpted knit upper, an icy sole, and a new way to lace up.",
    status: "Not yet verified",
    detail:
      "Included in the app’s shoe catalog. OpenAdapt connection and control have not been verified on this model.",
    photoSource: "https://www.goat.com/sneakers/adapt-bb-black-ao2582-001",
  },
  {
    id: "adapt-bb-2",
    brand: "Nike Adapt",
    model: "BB 2.0",
    year: "2020",
    colorway: "NBA ASG 2020",
    image: "/images/adapt-bb-2.jpg",
    width: 1250,
    height: 660,
    verified: false,
    description:
      "The second chapter on court. A bolder silhouette, textured Swoosh, and self-lacing design built to stand out.",
    status: "Not yet verified",
    detail:
      "Included in the app’s shoe catalog. OpenAdapt connection and control have not been verified on this model.",
    photoSource:
      "https://www.goat.com/sneakers/adapt-bb-2-0-all-star-2020-cv2441-001",
  },
  {
    id: "adapt-huarache",
    brand: "Nike Adapt",
    model: "Huarache",
    year: "2019",
    colorway: "White / Black",
    image: "/images/adapt-huarache.jpg",
    width: 1250,
    height: 627,
    verified: false,
    description:
      "A familiar icon, reimagined. The Huarache’s unmistakable shape meets the possibilities of a connected shoe.",
    status: "Not yet verified",
    detail:
      "Included in the app’s shoe catalog. OpenAdapt connection and control have not been verified on this model.",
    photoSource:
      "https://www.goat.com/sneakers/adapt-huarache-white-black-bv6397-110",
  },
  {
    id: "jordan-11-adapt",
    brand: "Air Jordan",
    model: "11 Adapt",
    year: "2020",
    colorway: "White",
    image: "/images/jordan-11-adapt.jpg",
    width: 1250,
    height: 789,
    verified: false,
    description:
      "Twenty-five years of an icon. Patent leather, an icy outsole, and an electric new chapter for the Jordan 11.",
    status: "Not yet verified",
    detail:
      "Included in the app’s shoe catalog. OpenAdapt connection and control have not been verified on this model.",
    photoSource:
      "https://www.goat.com/sneakers/air-jordan-11-adapt-25th-anniversary-da7990-100",
  },
];

export const shoes = models.map((shoe) => ({
  ...shoe,
  // StockX stays a regular link while its affiliate enrollment is pending.
  links: [
    {
      name: "StockX",
      url: stockxSearchUrl(shoe),
      affiliate: false,
    },
    {
      name: "eBay",
      url: ebayAffiliateUrl(shoe),
      affiliate: true,
    },
  ] satisfies MarketplaceLink[],
}));
