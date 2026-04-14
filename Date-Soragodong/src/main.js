import React from "react";
import { createRoot } from "react-dom/client";
import { createInstance, HackleProvider } from "@hackler/react-sdk";

import { App } from "./app.js";
import { ResultPage } from "./ResultPage.js";
import "./styles.css";

const hackleClient = createInstance("BqA2Ey8jDNxzfOnJoEcQO0NE4LIIHXvP");

const container = document.querySelector("#app");

if (!container) {
  throw new Error("App root not found");
}

// Client-side routing: /result -> ResultPage, everything else -> App
const path = window.location.pathname;
const Component = path.startsWith("/result") ? ResultPage : App;

createRoot(container).render(
  React.createElement(HackleProvider, { hackleClient },
    React.createElement(Component)
  )
);
