import { useState } from "react";
import { Check } from "lucide-react";

const tools = [
  { name: "Check List", color: "#E9C95A", image: "/assets/checklist.png" },
  { name: "Timezone", color: "#B88FD2", image: "/assets/timezone.png" },
  { name: "Currency", color: "#8DBFDF", image: "/assets/currency.png" },
  { name: "Insurance", color: "#E68185", image: "/assets/insurance.png" },
  { name: "eSIM", color: "#EFB66A", image: "/assets/sim.png" },
  { name: "Transport", color: "#E68185", image: "/assets/transport.png" },
  { name: "Security", color: "#E68185", image: "/assets/security.png" },
  { name: "Residency", color: "#E58EA5", image: "/assets/calendar.png" },
];

export function App() {
  const [selected, setSelected] = useState(tools[0].name);
  const activeTool = tools.find((tool) => tool.name === selected) ?? tools[0];

  return (
    <main className="mobile-prototype">
      <section className="screen" aria-label="Quick Tools icon preview">
        <header className="topbar">
          <div>
            <p className="eyebrow">NOMAD KIT</p>
            <h1>Quick Tools</h1>
          </div>
          <div className="avatar" aria-hidden="true">NK</div>
        </header>

        <div className="intro">
          <p>Make the next decision feel lighter.</p>
          <span>Icon direction preview</span>
        </div>

        <div className="tool-strip" role="list" aria-label="Quick Tools">
          {tools.map(({ name, color, image }) => {
            const isSelected = name === selected;
            return (
              <button
                className={`tool ${isSelected ? "is-selected" : ""}`}
                key={name}
                type="button"
                onClick={() => setSelected(name)}
                aria-pressed={isSelected}
              >
                <span className="icon-shell" style={{ backgroundColor: color, "--accent": color }}>
                  <img src={image} alt="" />
                </span>
                <span className="tool-label">{name}</span>
              </button>
            );
          })}
        </div>

        <div className="selection" style={{ "--accent": activeTool.color }}>
          <div className="selection-icon">
            <img src={activeTool.image} alt="" />
          </div>
          <div>
            <p className="selection-kicker">SELECTED TOOL</p>
            <h2>{activeTool.name}</h2>
            <p className="selection-copy">Tap another icon to compare the color system.</p>
          </div>
          <Check className="selection-check" aria-hidden="true" strokeWidth={3} />
        </div>

        <p className="footer-note">Preview only · no app changes made</p>
      </section>
    </main>
  );
}
