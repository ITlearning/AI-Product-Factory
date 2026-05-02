import { StrictMode } from "react";
import { createRoot } from "react-dom/client";

import { App } from "./App.jsx";

const container = document.querySelector("#app");

if (!container) {
  throw new Error("App root #app not found");
}

createRoot(container).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
