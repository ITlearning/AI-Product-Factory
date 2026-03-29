import React from "react";
import { createRoot } from "react-dom/client";

import { App } from "./app.js";
import "./styles.css";

const container = document.querySelector("#app");

if (!container) {
  throw new Error("App root not found");
}

createRoot(container).render(React.createElement(App));
