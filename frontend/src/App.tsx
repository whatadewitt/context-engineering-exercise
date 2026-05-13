import { useState, useEffect } from "react";
import { Catalog } from "./components/Catalog";
import { Watchlist } from "./components/Watchlist";
import { RecentlyWatched } from "./components/RecentlyWatched";

type Tab = "watchlist" | "catalog" | "recent";
type Theme = "light" | "dark";

function getSystemTheme(): Theme {
  return window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
}

function getInitialTheme(): Theme {
  const stored = localStorage.getItem("theme") as Theme | null;
  return stored ?? getSystemTheme();
}

export function App() {
  const [tab, setTab] = useState<Tab>("watchlist");
  const [theme, setTheme] = useState<Theme>(getInitialTheme);

  useEffect(() => {
    document.documentElement.setAttribute("data-theme", theme);
    localStorage.setItem("theme", theme);
  }, [theme]);

  const toggleTheme = () => setTheme(t => (t === "dark" ? "light" : "dark"));

  return (
    <div className="app">
      <div className="app-header">
        <h1>🎬 Watchlist</h1>
        <button className="theme-toggle" onClick={toggleTheme} aria-label="Toggle theme">
          {theme === "dark" ? "☀️ Light mode" : "🌙 Dark mode"}
        </button>
      </div>
      <div className="tabs">
        <button className={tab === "watchlist" ? "active" : ""} onClick={() => setTab("watchlist")}>
          My Watchlist
        </button>
        <button className={tab === "catalog" ? "active" : ""} onClick={() => setTab("catalog")}>
          Browse Catalog
        </button>
        <button className={tab === "recent" ? "active" : ""} onClick={() => setTab("recent")}>
          Watched Today
        </button>
      </div>
      {tab === "watchlist" && <Watchlist />}
      {tab === "catalog" && <Catalog />}
      {tab === "recent" && <RecentlyWatched />}
    </div>
  );
}
