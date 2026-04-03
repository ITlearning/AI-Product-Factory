import * as developerDict from "./developer.js";
import * as designerDict from "./designer.js";

const DICTIONARIES = {
  developer: developerDict,
  designer: designerDict,
};

export function getDictionary(categoryId) {
  return DICTIONARIES[categoryId] ?? DICTIONARIES["developer"];
}
