import React from "react";
import { createRoot } from "react-dom/client";

import { App } from "./app.js";
import { ResultPage } from "./ResultPage.js";
import "./styles.css";

const container = document.querySelector("#app");

if (!container) {
  throw new Error("App root not found");
}

// Client-side routing: /result -> ResultPage, everything else -> App
const path = window.location.pathname;
const Component = path.startsWith("/result") ? ResultPage : App;

createRoot(container).render(React.createElement(Component));
