/** Launch controls: never advertise a download or public source until it exists. */
export const site = {
  name: "OpenAdapt",
  url: "https://openadapt.app",
  repo: "https://github.com/GianlucaMinoprio/openAdapt",
  repositoryPublic: false,
  branch: "master",
  testflight: "",
  appStore: "",
};
export const source = (path: string) =>
  `${site.repo}/tree/${site.branch}/${path}`;
