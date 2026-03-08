#!/usr/bin/env python3
"""Cursor usage analysis: Ethan vs Murdad (Jan 2026 billing period)."""

import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import seaborn as sns
from pathlib import Path
import textwrap

sns.set_theme(style="whitegrid", palette="colorblind")
plt.rcParams.update({
    "figure.dpi": 150,
    "savefig.bbox": "tight",
    "font.size": 11,
})

DATA_DIR = Path(__file__).resolve().parent.parent
OUT_DIR = Path(__file__).resolve().parent / "charts"
OUT_DIR.mkdir(exist_ok=True)

COLORS = {"Ethan": "#2196F3", "Murdad": "#FF9800"}


def load(name: str) -> pd.DataFrame:
    path = DATA_DIR / f"jan2026-cursor-{name.lower()}.csv"
    df = pd.read_csv(path)
    df["Date"] = pd.to_datetime(df["Date"])
    df["Day"] = df["Date"].dt.date
    df["Hour"] = df["Date"].dt.hour
    df["Weekday"] = df["Date"].dt.day_name()
    df["User"] = name
    numeric_cols = [
        "Input (w/ Cache Write)", "Input (w/o Cache Write)",
        "Cache Read", "Output Tokens", "Total Tokens", "Cost",
    ]
    for c in numeric_cols:
        df[c] = pd.to_numeric(df[c], errors="coerce").fillna(0)
    df = df[df["Kind"] != "Errored, No Charge"]
    return df


ethan = load("Ethan")
murdad = load("Murdad")
both = pd.concat([ethan, murdad], ignore_index=True)


# ── Summary stats ────────────────────────────────────────────────────────
def summary(df: pd.DataFrame, name: str) -> dict:
    return {
        "User": name,
        "Total Requests": len(df),
        "Active Days": df["Day"].nunique(),
        "Date Range": f"{df['Date'].min().date()} → {df['Date'].max().date()}",
        "Total Cost ($)": round(df["Cost"].sum(), 2),
        "Avg Cost/Request ($)": round(df["Cost"].mean(), 4),
        "Total Tokens": int(df["Total Tokens"].sum()),
        "Total Output Tokens": int(df["Output Tokens"].sum()),
        "Max Mode Requests": int((df["Max Mode"] == "Yes").sum()),
        "Max Mode %": round((df["Max Mode"] == "Yes").mean() * 100, 1),
        "Avg Requests/Day": round(len(df) / df["Day"].nunique(), 1),
        "Median Cost/Request ($)": round(df["Cost"].median(), 4),
        "Models Used": ", ".join(sorted(df["Model"].unique())),
        "Requests using 'auto'": int((df["Model"] == "auto").sum()),
    }

s_e = summary(ethan, "Ethan")
s_m = summary(murdad, "Murdad")

summary_text = []
summary_text.append("=" * 70)
summary_text.append("CURSOR USAGE ANALYSIS — Ethan vs Murdad  (Jan 2026 billing period)")
summary_text.append("=" * 70)
for s in [s_e, s_m]:
    summary_text.append(f"\n── {s['User']} ──")
    for k, v in s.items():
        if k == "User":
            continue
        summary_text.append(f"  {k:30s}: {v}")

ratio_requests = s_e["Total Requests"] / s_m["Total Requests"]
ratio_cost = s_e["Total Cost ($)"] / s_m["Total Cost ($)"]
ratio_tokens = s_e["Total Tokens"] / s_m["Total Tokens"]

summary_text.append("\n── Comparison Ratios (Ethan / Murdad) ──")
summary_text.append(f"  Requests ratio:  {ratio_requests:.2f}x")
summary_text.append(f"  Cost ratio:      {ratio_cost:.2f}x")
summary_text.append(f"  Token ratio:     {ratio_tokens:.2f}x")

auto_e = (ethan["Model"] == "auto").sum()
auto_m = (murdad["Model"] == "auto").sum()
summary_text.append("\n── Key Insight: Why Ethan's Usage Is Higher ──")
summary_text.append(textwrap.fill(
    f"Ethan made {s_e['Total Requests']} requests vs Murdad's {s_m['Total Requests']} "
    f"({ratio_requests:.1f}x more). Ethan uses the 'auto' model for {auto_e} requests "
    f"({auto_e/len(ethan)*100:.0f}% of total), which are typically lighter agentic sub-calls "
    f"(lower cost each). Murdad uses 'auto' for only {auto_m} requests "
    f"({auto_m/len(murdad)*100:.0f}%). Murdad relies heavily on claude-4.6-opus-high-thinking "
    f"with Max Mode enabled ({s_m['Max Mode %']}% vs {s_e['Max Mode %']}%), making fewer but "
    f"more expensive calls. Ethan's pattern is high-frequency, lighter requests spread across "
    f"more hours; Murdad's is fewer, heavier sessions.",
    width=72,
))

summary_report = "\n".join(summary_text)
print(summary_report)
(OUT_DIR / "summary_report.txt").write_text(summary_report)


# ── Chart 1: Total requests & cost side by side ─────────────────────────
fig, axes = plt.subplots(1, 3, figsize=(15, 5))

users = ["Ethan", "Murdad"]
vals_req = [s_e["Total Requests"], s_m["Total Requests"]]
vals_cost = [s_e["Total Cost ($)"], s_m["Total Cost ($)"]]
vals_tokens = [s_e["Total Tokens"] / 1e6, s_m["Total Tokens"] / 1e6]

for ax, vals, title, ylabel in zip(
    axes,
    [vals_req, vals_cost, vals_tokens],
    ["Total Requests", "Total Cost ($)", "Total Tokens (millions)"],
    ["Requests", "USD", "Millions"],
):
    bars = ax.bar(users, vals, color=[COLORS[u] for u in users], edgecolor="white", width=0.5)
    ax.set_title(title, fontweight="bold")
    ax.set_ylabel(ylabel)
    for bar, v in zip(bars, vals):
        label = f"{v:,.0f}" if v > 100 else f"${v:,.2f}"
        ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height(),
                label, ha="center", va="bottom", fontweight="bold", fontsize=10)

fig.suptitle("Overall Usage Comparison", fontsize=14, fontweight="bold", y=1.02)
fig.tight_layout()
fig.savefig(OUT_DIR / "01_overall_comparison.png")
plt.close()


# ── Chart 2: Daily request count over time ───────────────────────────────
fig, ax = plt.subplots(figsize=(14, 5))
for name, df in [("Ethan", ethan), ("Murdad", murdad)]:
    daily = df.groupby("Day").size().reset_index(name="count")
    daily["Day"] = pd.to_datetime(daily["Day"])
    ax.plot(daily["Day"], daily["count"], marker="o", ms=4, label=name,
            color=COLORS[name], alpha=0.85, linewidth=1.5)
ax.set_title("Daily Request Count Over Time", fontweight="bold")
ax.set_ylabel("Requests")
ax.xaxis.set_major_formatter(mdates.DateFormatter("%b %d"))
ax.xaxis.set_major_locator(mdates.DayLocator(interval=2))
plt.xticks(rotation=45)
ax.legend()
fig.tight_layout()
fig.savefig(OUT_DIR / "02_daily_requests.png")
plt.close()


# ── Chart 3: Daily cost over time ────────────────────────────────────────
fig, ax = plt.subplots(figsize=(14, 5))
for name, df in [("Ethan", ethan), ("Murdad", murdad)]:
    daily = df.groupby("Day")["Cost"].sum().reset_index()
    daily["Day"] = pd.to_datetime(daily["Day"])
    ax.bar(daily["Day"] + pd.Timedelta(hours=-6 if name == "Ethan" else 6),
           daily["Cost"], width=0.4, label=name, color=COLORS[name], alpha=0.8)
ax.set_title("Daily Cost ($) Over Time", fontweight="bold")
ax.set_ylabel("Cost ($)")
ax.xaxis.set_major_formatter(mdates.DateFormatter("%b %d"))
ax.xaxis.set_major_locator(mdates.DayLocator(interval=2))
plt.xticks(rotation=45)
ax.legend()
fig.tight_layout()
fig.savefig(OUT_DIR / "03_daily_cost.png")
plt.close()


# ── Chart 4: Model distribution ─────────────────────────────────────────
fig, axes = plt.subplots(1, 2, figsize=(14, 5))
for ax, (name, df) in zip(axes, [("Ethan", ethan), ("Murdad", murdad)]):
    model_counts = df["Model"].value_counts()
    wedges, texts, autotexts = ax.pie(
        model_counts.values, labels=None, autopct="%1.1f%%",
        startangle=90, pctdistance=0.75,
    )
    ax.set_title(f"{name} — Model Distribution", fontweight="bold")
    short_labels = [m.replace("claude-4.6-opus-high-thinking", "cl-4.6-opus-ht")
                     .replace("claude-4.5-opus-high-thinking", "cl-4.5-opus-ht")
                    for m in model_counts.index]
    ax.legend(short_labels, loc="lower center", fontsize=8, ncol=1,
              bbox_to_anchor=(0.5, -0.15))
fig.suptitle("Model Usage Distribution", fontsize=14, fontweight="bold", y=1.02)
fig.tight_layout()
fig.savefig(OUT_DIR / "04_model_distribution.png")
plt.close()


# ── Chart 5: Hourly activity heatmap ─────────────────────────────────────
fig, axes = plt.subplots(1, 2, figsize=(14, 5), sharey=True)
for ax, (name, df) in zip(axes, [("Ethan", ethan), ("Murdad", murdad)]):
    hourly = df.groupby("Hour").size()
    hourly = hourly.reindex(range(24), fill_value=0)
    ax.bar(hourly.index, hourly.values, color=COLORS[name], edgecolor="white", alpha=0.85)
    ax.set_title(f"{name} — Requests by Hour (UTC)", fontweight="bold")
    ax.set_xlabel("Hour of Day (UTC)")
    ax.set_ylabel("Requests")
    ax.set_xticks(range(0, 24, 2))
fig.tight_layout()
fig.savefig(OUT_DIR / "05_hourly_activity.png")
plt.close()


# ── Chart 6: Max Mode usage ─────────────────────────────────────────────
fig, ax = plt.subplots(figsize=(8, 5))
max_mode_data = pd.DataFrame({
    "User": ["Ethan", "Ethan", "Murdad", "Murdad"],
    "Max Mode": ["Yes", "No", "Yes", "No"],
    "Count": [
        (ethan["Max Mode"] == "Yes").sum(),
        (ethan["Max Mode"] == "No").sum(),
        (murdad["Max Mode"] == "Yes").sum(),
        (murdad["Max Mode"] == "No").sum(),
    ],
})
sns.barplot(data=max_mode_data, x="User", y="Count", hue="Max Mode", ax=ax,
            palette={"Yes": "#E53935", "No": "#43A047"})
ax.set_title("Max Mode Usage Comparison", fontweight="bold")
ax.set_ylabel("Number of Requests")
for container in ax.containers:
    ax.bar_label(container, fontweight="bold")
fig.tight_layout()
fig.savefig(OUT_DIR / "06_max_mode.png")
plt.close()


# ── Chart 7: Cost distribution (histogram) ──────────────────────────────
fig, axes = plt.subplots(1, 2, figsize=(14, 5), sharey=True)
for ax, (name, df) in zip(axes, [("Ethan", ethan), ("Murdad", murdad)]):
    costs = df[df["Cost"] > 0]["Cost"]
    ax.hist(costs, bins=40, color=COLORS[name], edgecolor="white", alpha=0.85)
    ax.axvline(costs.median(), color="red", ls="--", lw=1.5, label=f"Median: ${costs.median():.2f}")
    ax.axvline(costs.mean(), color="black", ls=":", lw=1.5, label=f"Mean: ${costs.mean():.2f}")
    ax.set_title(f"{name} — Cost per Request Distribution", fontweight="bold")
    ax.set_xlabel("Cost ($)")
    ax.set_ylabel("Frequency")
    ax.legend(fontsize=9)
fig.tight_layout()
fig.savefig(OUT_DIR / "07_cost_distribution.png")
plt.close()


# ── Chart 8: Cumulative cost over time ───────────────────────────────────
fig, ax = plt.subplots(figsize=(14, 5))
for name, df in [("Ethan", ethan), ("Murdad", murdad)]:
    sorted_df = df.sort_values("Date")
    sorted_df["Cumulative Cost"] = sorted_df["Cost"].cumsum()
    ax.plot(sorted_df["Date"], sorted_df["Cumulative Cost"],
            label=name, color=COLORS[name], linewidth=2)
ax.set_title("Cumulative Cost Over Time", fontweight="bold")
ax.set_ylabel("Cumulative Cost ($)")
ax.xaxis.set_major_formatter(mdates.DateFormatter("%b %d"))
ax.xaxis.set_major_locator(mdates.DayLocator(interval=2))
plt.xticks(rotation=45)
ax.legend()
fig.tight_layout()
fig.savefig(OUT_DIR / "08_cumulative_cost.png")
plt.close()


# ── Chart 9: Average tokens per request ──────────────────────────────────
fig, ax = plt.subplots(figsize=(10, 5))
token_cols = ["Input (w/ Cache Write)", "Input (w/o Cache Write)",
              "Cache Read", "Output Tokens"]
short_labels = ["Input\n(Cache Write)", "Input\n(No Cache)", "Cache Read", "Output"]
x_positions = range(len(token_cols))
width = 0.35
for i, (name, df) in enumerate([("Ethan", ethan), ("Murdad", murdad)]):
    means = [df[c].mean() for c in token_cols]
    offset = -width / 2 + i * width
    bars = ax.bar([p + offset for p in x_positions], means, width=width,
                  label=name, color=COLORS[name], alpha=0.85, edgecolor="white")
ax.set_title("Average Tokens per Request by Type", fontweight="bold")
ax.set_ylabel("Average Tokens")
ax.set_xticks(x_positions)
ax.set_xticklabels(short_labels)
ax.legend()
ax.ticklabel_format(style="plain", axis="y")
fig.tight_layout()
fig.savefig(OUT_DIR / "09_avg_tokens_per_request.png")
plt.close()


# ── Chart 10: Weekday activity ───────────────────────────────────────────
fig, ax = plt.subplots(figsize=(10, 5))
day_order = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
for name, df in [("Ethan", ethan), ("Murdad", murdad)]:
    wk = df["Weekday"].value_counts().reindex(day_order, fill_value=0)
    ax.plot(wk.index, wk.values, marker="o", ms=6, label=name,
            color=COLORS[name], linewidth=2)
ax.set_title("Requests by Day of Week", fontweight="bold")
ax.set_ylabel("Total Requests")
ax.legend()
plt.xticks(rotation=30)
fig.tight_layout()
fig.savefig(OUT_DIR / "10_weekday_activity.png")
plt.close()


# ── Chart 11: auto vs explicit model — cost breakdown ────────────────────
fig, ax = plt.subplots(figsize=(10, 5))
categories = []
for name, df in [("Ethan", ethan), ("Murdad", murdad)]:
    auto_cost = df[df["Model"] == "auto"]["Cost"].sum()
    explicit_cost = df[df["Model"] != "auto"]["Cost"].sum()
    categories.append({"User": name, "Type": "auto", "Cost": auto_cost})
    categories.append({"User": name, "Type": "Explicit Model", "Cost": explicit_cost})
cat_df = pd.DataFrame(categories)
sns.barplot(data=cat_df, x="User", y="Cost", hue="Type", ax=ax,
            palette={"auto": "#7E57C2", "Explicit Model": "#26A69A"})
ax.set_title("Cost Breakdown: auto vs Explicit Model Selection", fontweight="bold")
ax.set_ylabel("Total Cost ($)")
for container in ax.containers:
    ax.bar_label(container, fmt="$%.1f", fontweight="bold")
fig.tight_layout()
fig.savefig(OUT_DIR / "11_auto_vs_explicit_cost.png")
plt.close()


# ── Chart 12: Request intensity (requests per active hour per day) ───────
fig, axes = plt.subplots(1, 2, figsize=(14, 5))
for ax, (name, df) in zip(axes, [("Ethan", ethan), ("Murdad", murdad)]):
    day_hour = df.groupby(["Day", "Hour"]).size().reset_index(name="count")
    pivot = day_hour.pivot(index="Day", columns="Hour", values="count").fillna(0)
    pivot = pivot.reindex(columns=range(24), fill_value=0)
    sns.heatmap(pivot.T, ax=ax, cmap="YlOrRd", cbar_kws={"label": "Requests"},
                yticklabels=2)
    ax.set_title(f"{name} — Activity Heatmap (Day × Hour UTC)", fontweight="bold", fontsize=10)
    ax.set_xlabel("Day Index")
    ax.set_ylabel("Hour (UTC)")
fig.tight_layout()
fig.savefig(OUT_DIR / "12_activity_heatmap.png")
plt.close()


print(f"\n✓ All charts saved to {OUT_DIR}/")
print("  Generated 12 charts + summary_report.txt")
