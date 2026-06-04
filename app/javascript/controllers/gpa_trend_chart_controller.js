import { Controller } from "@hotwired/stimulus";
import * as d3 from "d3";

export default class extends Controller {
  static values = { data: Object };

  _svg = null;
  _resizeObserver = null;

  connect() {
    this._draw();
    this._resizeObserver = new ResizeObserver(() => {
      this._svg?.remove();
      this._svg = null;
      this._draw();
    });
    this._resizeObserver.observe(this.element);
  }

  disconnect() {
    this._resizeObserver?.disconnect();
  }

  _draw() {
    const containerWidth = this.element.clientWidth;
    const containerHeight = this.element.clientHeight;
    if (containerWidth < 50 || containerHeight < 50) return;

    const margin = { top: 24, right: 24, bottom: 40, left: 44 };
    const width = containerWidth - margin.left - margin.right;
    const height = containerHeight - margin.top - margin.bottom;

    const points = this.dataValue.values || [];
    if (points.length < 2) return;

    const svg = d3
      .select(this.element)
      .append("svg")
      .attr("width", containerWidth)
      .attr("height", containerHeight);

    this._svg = svg;

    const g = svg
      .append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`);

    // Scales
    const xScale = d3
      .scalePoint()
      .domain(points.map((d) => d.year))
      .range([0, width])
      .padding(0);

    const yMin = Math.floor((d3.min(points, (d) => d.gpa) - 0.1) * 10) / 10;
    const yMax = Math.ceil((d3.max(points, (d) => d.gpa) + 0.1) * 10) / 10;

    const yScale = d3
      .scaleLinear()
      .domain([yMin, yMax])
      .range([height, 0])
      .nice();

    // Gradient fill below line
    const gradientId = `gpa-area-gradient-${Math.random().toString(36).slice(2)}`;
    const defs = svg.append("defs");
    const gradient = defs
      .append("linearGradient")
      .attr("id", gradientId)
      .attr("x1", 0)
      .attr("x2", 0)
      .attr("y1", 0)
      .attr("y2", 1);
    gradient
      .append("stop")
      .attr("offset", "0%")
      .attr("stop-color", "var(--color-blue-500)")
      .attr("stop-opacity", 0.12);
    gradient
      .append("stop")
      .attr("offset", "100%")
      .attr("stop-color", "var(--color-blue-500)")
      .attr("stop-opacity", 0);

    // Area fill
    const area = d3
      .area()
      .x((d) => xScale(d.year))
      .y0(height)
      .y1((d) => yScale(d.gpa))
      .curve(d3.curveMonotoneX);

    g.append("path")
      .datum(points)
      .attr("fill", `url(#${gradientId})`)
      .attr("d", area);

    // Horizontal reference line at 3.0
    if (yMin <= 3.0 && yMax >= 3.0) {
      g.append("line")
        .attr("x1", 0)
        .attr("x2", width)
        .attr("y1", yScale(3.0))
        .attr("y2", yScale(3.0))
        .attr("stroke", "var(--color-gray-300)")
        .attr("stroke-dasharray", "4 4")
        .attr("stroke-width", 1);

      g.append("text")
        .attr("x", width)
        .attr("y", yScale(3.0) - 5)
        .attr("text-anchor", "end")
        .attr("fill", "var(--color-gray-400)")
        .style("font-size", "11px")
        .text("3.0 baseline");
    }

    // COVID annotation
    const covidYear = "2019-20";
    const covidPoint = points.find((d) => d.year === covidYear);
    if (covidPoint) {
      const cx = xScale(covidYear);
      g.append("line")
        .attr("x1", cx)
        .attr("x2", cx)
        .attr("y1", 0)
        .attr("y2", height)
        .attr("stroke", "var(--color-orange-400)")
        .attr("stroke-dasharray", "3 3")
        .attr("stroke-width", 1)
        .attr("opacity", 0.6);

      g.append("text")
        .attr("x", cx + 4)
        .attr("y", 14)
        .attr("fill", "var(--color-orange-500)")
        .style("font-size", "10px")
        .text("COVID");
    }

    // Trendline
    const line = d3
      .line()
      .x((d) => xScale(d.year))
      .y((d) => yScale(d.gpa))
      .curve(d3.curveMonotoneX);

    g.append("path")
      .datum(points)
      .attr("fill", "none")
      .attr("stroke", "var(--color-blue-500)")
      .attr("stroke-width", 2)
      .attr("stroke-linecap", "round")
      .attr("stroke-linejoin", "round")
      .attr("d", line);

    // X axis — show every other year label to avoid overlap
    const everyOtherYear = points
      .map((d) => d.year)
      .filter((_, i) => i % 2 === 0);

    g.append("g")
      .attr("transform", `translate(0,${height})`)
      .call(
        d3
          .axisBottom(xScale)
          .tickValues(everyOtherYear)
          .tickSize(0)
          .tickFormat((d) => d.slice(0, 4)),
      )
      .call((axis) => axis.select(".domain").remove())
      .selectAll("text")
      .attr("dy", "1.2em")
      .style("font-size", "11px")
      .attr("fill", "var(--color-gray-500)");

    // Y axis
    g.append("g")
      .call(
        d3
          .axisLeft(yScale)
          .ticks(4)
          .tickSize(-width)
          .tickFormat((d) => d.toFixed(2)),
      )
      .call((axis) => axis.select(".domain").remove())
      .call((axis) =>
        axis
          .selectAll(".tick line")
          .attr("stroke", "var(--color-gray-100)")
          .attr("stroke-dasharray", "2 2"),
      )
      .selectAll("text")
      .style("font-size", "11px")
      .attr("fill", "var(--color-gray-500)");

    // Invisible hit-target overlay + tooltip
    const tooltip = d3
      .select(this.element)
      .append("div")
      .attr(
        "class",
        "absolute bg-container border border-secondary rounded-lg px-3 py-2 text-sm pointer-events-none opacity-0",
      )
      .style("top", "0")
      .style("left", "0");

    const bisect = d3.bisector((d) => d.year).left;

    const overlay = g
      .append("rect")
      .attr("width", width)
      .attr("height", height)
      .attr("fill", "none")
      .attr("pointer-events", "all");

    const dot = g
      .append("circle")
      .attr("r", 5)
      .attr("fill", "var(--color-blue-500)")
      .attr("stroke", "var(--color-container)")
      .attr("stroke-width", 2)
      .attr("opacity", 0)
      .attr("pointer-events", "none");

    overlay
      .on("mousemove", (event) => {
        const [mouseX] = d3.pointer(event);
        const domain = xScale.domain();
        const step = width / (domain.length - 1);
        const idx = Math.max(
          0,
          Math.min(domain.length - 1, Math.round(mouseX / step)),
        );
        const d = points[idx];
        if (!d) return;

        const cx = xScale(d.year);
        const cy = yScale(d.gpa);

        dot.attr("cx", cx).attr("cy", cy).attr("opacity", 1);

        const tooltipHtml = `
          <div class="text-secondary text-xs mb-0.5">${d.year}</div>
          <div class="font-medium text-primary">${d.gpa.toFixed(2)} GPA</div>
        `;

        const containerRect = this.element.getBoundingClientRect();
        const tooltipWidth = 120;
        const leftPos =
          cx + margin.left + tooltipWidth > containerWidth
            ? cx + margin.left - tooltipWidth - 8
            : cx + margin.left + 8;

        tooltip
          .html(tooltipHtml)
          .style("opacity", 1)
          .style("left", `${leftPos}px`)
          .style("top", `${cy + margin.top - 30}px`);
      })
      .on("mouseleave", () => {
        dot.attr("opacity", 0);
        tooltip.style("opacity", 0);
      });
  }
}
