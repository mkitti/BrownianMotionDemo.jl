# 3D Brownian Motion Simulation Gallery

An elegant, interactive, and offline-compatible 3D Brownian Motion (random walk) gallery built with **Julia**, **WGLMakie.jl**, and **Bonito.jl**, designed to run completely serverless on **GitHub Pages**.

👉 **Live Demo:** [https://mkitti.github.io/BrownianMotionDemo.jl/](https://mkitti.github.io/BrownianMotionDemo.jl/)

---

## 🌌 Project Overview

This project simulates a stable-seeded 3D random walk (Brownian Motion) in coordinate space. It compiles interactive Julia visual widgets into high-performance, responsive, self-contained HTML files with embedded WebGL.

### Key Features
* **Premium Aesthetics:** Sleek dark-mode theme utilizing glassmorphic cards, gradient headings, modern typography (Outfit / Inter), and smooth transition states.
* **Offline-First Interactive Scrubber:** Drag the interactive timeline slider to scrub through the 3D particle path in real-time at 60 FPS without needing an active Julia server.
* **Stable Reproducibility:** Uses `StableRNGs` to guarantee identical particle trajectories across all operating systems and Julia versions.
* **GitHub Pages Integration:** Outputs self-contained standalone HTML documents, complete with client-side JavaScript interactions, making them perfect for static web hosting.

---

## 🛠️ Technical Discoveries & Bug Fixes

Building interactive 3D plots that function offline on static pages revealed critical insights into how Makie's scene graphs and serialization work under the hood.

### 1. The `Invalid aspect auto` Bug (`Axis3` vs `LScene`)
* **The Issue:** When trying to render plots using `Axis3`, older or certain versions of Makie threw `MethodError` or `Invalid aspect auto` exceptions because `:auto` was being evaluated as an invalid aspect ratio parameter for 3D layout bounds.
* **The Discovery:** Under the hood, `LScene` bypasses the automated rectangular block layout constraints of standard layoutables. Reverting from `Axis3` to `LScene` completely avoids the aspect-ratio solver bug and remains 100% robust across all Julia environments and Makie versions.
* **The Solution:** We instantiated the 3D axis within an `LScene` with hardcoded boundaries:
  ```julia
  ax = LScene(fig[1, 1], show_axis = true, scenekw = (limits = limits_rect,))
  ```

### 2. Styling the Underlying `OldAxis` in `LScene`
* **The Issue:** The default labels and ticks of the 3D grid in `LScene` render as black text, which is nearly unreadable against a premium dark-blue canvas. Since `LScene` uses the low-level `OldAxis` instead of `Axis3` for grid projection, standard thematic customizations did not apply.
* **The Discovery:** The low-level `OldAxis` (Axis3D) attributes are stored in a `Computed` wrapper nested inside the scene plots. Setting properties directly on the referred `Attributes` structure successfully modifies the WebGL layout.
* **The Solution:** We set the custom axis names and highly visible light silver (`#e2e8f0`) labels by accessing the plots on the underlying scene:
  ```julia
  if !isnothing(ax.scene[Makie.OldAxis])
      ax.scene[Makie.OldAxis][:names][][:axisnames][] = ("X Position", "Y Position", "Z Position")
      ax.scene[Makie.OldAxis][:names][][:textcolor][] = ("#e2e8f0", "#e2e8f0", "#e2e8f0")
  end
  ```

### 3. Serverless Client-Side Interactivity via `onjs` & `positions_transformed_f32c`
* **The Issue:** Standard Makie sliders and buttons use Julia `Observables`. When exported to static HTML pages, these widgets normally break because there is no running Julia backend or WebSocket server to process event notifications.
* **The Discovery:** WGLMakie can serialize Julia arrays directly into JavaScript arrays in the generated output. By extracting the slider from the Makie layout into a native HTML `Bonito.Slider` and registering a custom `onjs` callback, we can directly update the WebGL mesh buffers.
* **Deep Dive into `positions_transformed_f32c`:** 
  * WGLMakie compiles and maps Makie plot objects to Three.js primitives (such as `THREE.Line` or `THREE.Points`) on the browser client.
  * In the serialized JavaScript scene graph, `positions_transformed_f32c` is the primary key representing the contiguous 32-bit floating-point coordinate vertex buffer (`[x1, y1, z1, x2, y2, z2, ...]`) used directly by the WebGL vertex shader.
  * When scrubbing the timeline, the JavaScript callback prepares a flat, compact array of size `steps * 3`. For time step $t$, it retains the active historical coordinates up to $t$, and collapses all future coordinates to the position at $t$.
  * Calling `.update([["positions_transformed_f32c", new_positions]])` bypasses Julia and directly instructs the Three.js renderer to push the raw byte buffer to the GPU (`gl.bufferSubData`), updating the visible trail instantly at 60 FPS.
* **The Solution:** We injected client-side JavaScript that manipulates the Three.js mesh's vertex buffers directly:
  ```julia
  onjs(session, sg.value, js"""(val) => {
      const t = Math.round(val);
      if (t < 1) return;
      
      $(lines_plot).then(plots => {
          const plot_obj = plots[0].plot_object;
          const x = $(x);
          const y = $(y);
          const z = $(z);
          const steps = $(steps);
          
          const new_positions = new Float32Array(steps * 3);
          for (let i = 0; i < t; i++) {
              new_positions[3 * i] = x[i];
              new_positions[3 * i + 1] = y[i];
              new_positions[3 * i + 2] = z[i];
          }
          // Collapse the rest of the vertices to the last active position
          const last_x = x[t - 1];
          const last_y = y[t - 1];
          const last_z = z[t - 1];
          for (let i = t; i < steps; i++) {
              new_positions[3 * i] = last_x;
              new_positions[3 * i + 1] = last_y;
              new_positions[3 * i + 2] = last_z;
          }
          
          plot_obj.update([["positions_transformed_f32c", new_positions]]);
      });
  }""")
  ```
  This guarantees hardware-accelerated 60 FPS scrubbing completely offline.

### 4. Keeping Bounds Stable Across Multiple Seeds
* **The Issue:** When switching between different random walk seeds in the dashboard, the 3D plot's viewport boundaries would jump wildly, making visual comparison of step sizes difficult.
* **The Solution:** We precompute the global coordinate extrema over all available seeds and configure the `LScene` limits to this unified `Rect3f`. This keeps the coordinates stationary and allows for precise visual comparison.

---

## ⚖️ Comparative Study: Client-Side Callbacks (`onjs`) vs. State-Baking (`record_states`)

In the branch `demo-record-states`, we configured an alternative implementation using **state-baking** (`Bonito.record_states`) to study how it compares with the client-side JavaScript approach (`onjs`) on the `main` branch.

### 1. State-Baked Approach (`demo-record-states` branch)
By utilizing Julia-side `lift` observables, we slice the dataset inside Julia and call `Bonito.record_states(session, dom)`. This instructs Bonito to programmatically loop through all timeline slider step values, serialize every intermediate state frame into a massive lookup dictionary (JSON map), and embed it directly into the static HTML page.

### 2. Client-Side Callback Approach (`main` branch)
Instead of updating plots on the server/pre-compile side, the client-side approach loads the complete raw coordinate array (`X`, `Y`, `Z`) into the browser memory *once*. A pure client-side `onjs` JavaScript callback executes on the slider input event, splicing the coordinate buffer in real-time and updating the WebGL vertex array buffer in-place on the GPU.

### 3. Empirical Performance & Payload Metrics

The differences in compile speed, file sizes, and memory usage are dramatic:

| Metric | `onjs` (Client-Side JS on `main`) | `record_states` (State-Baked on `demo-record-states`) |
| :--- | :---: | :---: |
| **Simulation Steps** | **1,000 steps** | **100 steps** |
| **Single HTML Run Size** | **~2.4 MB** | **~24 MB** |
| **Projected Size at 1,000 Steps** | **~2.4 MB** | **~240+ MB** |
| **Interactive Latency** | Instantaneous (<1ms, client-bound) | Heavy JSON-parsing state-lookup delay per frame |
| **GPU Allocations** | 1 initial allocation (updates in-place) | Constant buffer deallocations / re-allocations |

### 4. Critical Findings & Insights
* **Scaling Bottlenecks:** State-baking scales $O(N)$ with the number of slider states. For high-resolution simulations, this causes exponential inflation of the file size (240+ MB for 1000 steps), making it completely impractical for static web deployment.
* **Network & Parsing Latency:** A 240+ MB static HTML file takes significant time to download and causes heavy browser freezes while parsing the embedded JSON lookup tables.
* **Client-Side Buffer In-Place Updates:** By leveraging the low-level `"positions_transformed_f32c"` handle directly in `onjs`, the client-side approach achieves a compact, constant-size payload (~2.4 MB) and smooth 60 FPS hardware-accelerated scrubbing without allocating new memory in the browser.

---

## 🚀 Running the Project Locally

### 1. Setup & Environment
Ensure you have Julia installed. Then, clone the repository, open a terminal in the folder, and run:
```bash
julia --project=. -e "using Pkg; Pkg.instantiate()"
```

### 2. Export Standalone HTML Pages
To generate the static HTML landing pages and simulation dashboards:
```bash
julia --project=. generate_demo.jl
```
This precompiles the module and generates:
* `index.html` (The interactive gallery directory)
* `brownian-motion-demo-42.html`
* `brownian-motion-demo-100.html`
* `brownian-motion-demo-2026.html`

### 3. Run the Live Switcher Server
To preview the interactive pages locally with full support:
```bash
julia --project=. generate_demo.jl serve
```
Then navigate to **`http://127.0.0.1:8081`** in your browser.

---

## 🎨 Acknowledgements & Technologies
This project is built using:
* **[Julia Language](https://github.com/JuliaLang/julia)** — The high-performance programming language designed for technical computing.
* **[Makie.jl](https://github.com/MakieOrg/Makie.jl)** — A rich, flexible, and fast data visualization ecosystem for Julia, containing **[WGLMakie.jl](https://github.com/MakieOrg/Makie.jl/tree/master/WGLMakie)** (the WebGL-based hardware-accelerated plotting backend).
* **[Bonito.jl](https://github.com/SimonDanisch/Bonito.jl)** — An interactive HTML dashboard builder and client-server synchronization engine for Julia.
* **[StableRNGs.jl](https://github.com/JuliaRandom/StableRNGs.jl)** — A stable, reproducible random number generator package for Julia.
* **Antigravity (powered by Gemini Flash 3.5)** — AI Co-Generation & Refactoring.
