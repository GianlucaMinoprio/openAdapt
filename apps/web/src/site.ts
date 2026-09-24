/** Website destinations. Download buttons activate when real release URLs exist. */
export const site = {
  name: "OpenAdapt",
  url: "https://openadapt.app",
  repo: "https://github.com/GianlucaMinoprio/openAdapt",
  branch: "master",
  testflight: "",
  appStore: "",
};
export const source = (path: string) =>
  `${site.repo}/tree/${site.branch}/${path}`;
