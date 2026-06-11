module JuliaExportStatic

using StableRNGs
using WGLMakie
using Bonito

export simulate_brownian_motion, build_app, main

# 1. Simulate Brownian Motion with a stable seed
function simulate_brownian_motion(steps=1000, dt=0.1, sigma=1.5, seed=42)
    # Use StableRNG for reproducible behavior across all systems & Julia versions
    rng = StableRNG(seed)
    
    # Pre-allocate trajectory
    x = zeros(steps)
    y = zeros(steps)
    z = zeros(steps)
    
    # Generate random increments using the stable RNG
    dx = randn(rng, steps - 1) .* (sigma * sqrt(dt))
    dy = randn(rng, steps - 1) .* (sigma * sqrt(dt))
    dz = randn(rng, steps - 1) .* (sigma * sqrt(dt))
    
    # Integrate to get position
    for t in 2:steps
        x[t] = x[t-1] + dx[t-1]
        y[t] = y[t-1] + dy[t-1]
        z[t] = z[t-1] + dz[t-1]
    end
    
    return x, y, z
end

# 2. Build the Bonito App
function build_app(steps=1000, dt=0.1, sigma=1.5, seed=42)
    # Generate trajectory
    x, y, z = simulate_brownian_motion(steps, dt, sigma, seed)
    
    app = App() do session
        # Create an elegant theme for the WGLMakie figure with highly visible gridlines
        theme = Theme(
            backgroundcolor = :transparent,
            textcolor = "#e2e8f0",
            fontsize = 14,
            font = "Roboto, sans-serif",
            Axis3 = (
                backgroundcolor = "#111827", # Deeper dark gray/slate background for contrast
                gridcolor = "#4b5563",       # Highly visible light gray gridlines
                gridwidth = 1.5,             # Thicker gridlines for better spatial sense
                xgridvisible = true,
                ygridvisible = true,
                zgridvisible = true,
                linecolor = "#6b7280",       # Higher contrast spines
                tickcolor = "#6b7280",       # Higher contrast ticks
                spinecolor = "#6b7280",
                perspectiveness = 0.5,
                azimuth = 1.27 * pi,         # Rotate view slightly for better 3D depth
                elevation = 0.2 * pi,
            )
        )
        
        # Apply theme
        with_theme(theme) do
            fig = Figure(size = (900, 720))
            
            # 1. Create structured multi-row layout using Makie's layout engine
            header_grid = fig[1, 1] = GridLayout()
            
            # 2. Add interactive slider at row 3
            sg = Makie.Slider(fig[3, 1], range = 1:steps, startvalue = steps)
            t_obs = sg.value
            
            # Explicitly configure heights of layout rows to prevent overlapping
            rowsize!(fig.layout, 1, Fixed(60))  # Structured space for Header Labels
            rowsize!(fig.layout, 2, Auto())     # Auto-expand the 3D Axis3 Plot
            rowsize!(fig.layout, 3, Fixed(35))  # Spaced height for the Slider
            
            # 3. Slice trajectory arrays dynamically based on the current slider value
            x_sub = lift(t -> x[1:t], t_obs)
            y_sub = lift(t -> y[1:t], t_obs)
            z_sub = lift(t -> z[1:t], t_obs)
            colors_sub = lift(t -> collect(1:t), t_obs)
            
            # Dynamic position of the particle at step t
            x_curr = lift(t -> [x[t]], t_obs)
            y_curr = lift(t -> [y[t]], t_obs)
            z_curr = lift(t -> [z[t]], t_obs)
            
            # 4. Structured Header Labels (Title in row 1, Subtitle in row 2 of header grid)
            title_text = lift(t -> "Interactive 3D Brownian Motion Path (t = $t / $steps)", t_obs)
            
            Makie.Label(
                header_grid[1, 1],
                title_text,
                fontsize = 18,
                font = :bold,
                color = "#f8fafc",
                halign = :center
            )
            
            Makie.Label(
                header_grid[2, 1],
                "Reproducible Generation • StableRNG seed: $seed",
                fontsize = 13,
                font = "Roboto, sans-serif",
                color = "#38bdf8",
                halign = :center
            )
            
            # 5. Place the 3D plot in row 2 of the main figure
            ax = Axis3(
                fig[2, 1],
                xlabel = "X Position",
                ylabel = "Y Position",
                zlabel = "Z Position",
            )
            
            # Plot the active trajectory line, with color reflecting time progress up to t
            lines!(
                ax, x_sub, y_sub, z_sub,
                color = colors_sub,
                colormap = :turbo,
                colorrange = (1.0, Float64(steps)), # Anchor colormap limits so colors stay stable
                linewidth = 3.5,
                label = "Path"
            )
            
            # Lift color corresponding to the current step t
            color_curr = lift(t -> [Float64(t)], t_obs)
            
            # Mark Start with a shaded 3D sphere matching the line's start color (t = 1)
            meshscatter!(
                ax,
                [x[1]], [y[1]], [z[1]],
                color = [1.0],
                colormap = :turbo,
                colorrange = (1.0, Float64(steps)),
                markersize = 1.0, # Physical radius in coordinates
                shading = true,
                label = "Start"
            )
            
            # Mark current particle position as a larger, dynamic shaded 3D sphere matching current time t
            meshscatter!(
                ax,
                x_curr, y_curr, z_curr,
                color = color_curr,
                colormap = :turbo,
                colorrange = (1.0, Float64(steps)),
                markersize = 1.4, # Slightly larger physical radius to stand out
                shading = true,
                label = "Particle"
            )
            
            # Modern Premium HTML Page wrapping the Makie canvas
            return DOM.div(
                style = """
                    min-height: 100vh;
                    background: linear-gradient(135deg, #0f172a 0%, #1e1b4b 100%);
                    color: #f8fafc;
                    font-family: 'Outfit', 'Inter', -apple-system, sans-serif;
                    padding: 2.5rem;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: flex-start;
                """,
                # Header card
                DOM.div(
                    style = """
                        text-align: center;
                        max-width: 800px;
                        margin-bottom: 2rem;
                    """,
                    DOM.h1(
                        "3D Brownian Motion Simulation",
                        style = """
                            font-size: 2.8rem;
                            font-weight: 800;
                            margin-bottom: 0.5rem;
                            background: linear-gradient(90deg, #38bdf8, #818cf8);
                            -webkit-background-clip: text;
                            -webkit-text-fill-color: transparent;
                            letter-spacing: -0.025em;
                        """
                    ),
                    DOM.p(
                        "Interactive WebGL rendering of a single particle performing a random walk in three dimensions.",
                        style = "font-size: 1.15rem; color: #94a3b8; line-height: 1.6;"
                    )
                ),
                
                # Interactive 3D Viewer Container (Card with glassmorphism/shadow)
                DOM.div(
                    style = """
                        background: rgba(30, 41, 59, 0.4);
                        backdrop-filter: blur(12px);
                        -webkit-backdrop-filter: blur(12px);
                        border: 1px solid rgba(255, 255, 255, 0.08);
                        border-radius: 1.5rem;
                        padding: 1.5rem;
                        box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
                        margin-bottom: 2rem;
                        width: 100%;
                        max-width: 950px;
                        display: flex;
                        justify-content: center;
                    """,
                    fig
                ),
                
                # Quick description / controls info card
                DOM.div(
                    style = """
                        display: flex;
                        gap: 1.5rem;
                        width: 100%;
                        max-width: 950px;
                        flex-wrap: wrap;
                    """,
                    DOM.div(
                        style = """
                            flex: 1;
                            min-width: 280px;
                            background: rgba(30, 41, 59, 0.25);
                            border-radius: 1rem;
                            padding: 1.25rem;
                            border: 1px solid rgba(255, 255, 255, 0.05);
                        """,
                        DOM.h3("💡 Interactive Controls", style="font-weight: 700; margin-top: 0; color: #38bdf8; margin-bottom: 0.5rem;"),
                        DOM.ul(
                            DOM.li("Left Click + Drag: Rotate the 3D space"),
                            DOM.li("Right Click + Drag: Pan across the canvas"),
                            DOM.li("Scroll Wheel: Zoom in and out"),
                            DOM.li("Slider (Bottom of Plot): Drag to scrub through simulation time"),
                            style = "padding-left: 1.25rem; margin: 0; color: #cbd5e1; line-height: 1.5;"
                        )
                    ),
                    DOM.div(
                        style = """
                            flex: 1;
                            min-width: 280px;
                            background: rgba(30, 41, 59, 0.25);
                            border-radius: 1rem;
                            padding: 1.25rem;
                            border: 1px solid rgba(255, 255, 255, 0.05);
                        """,
                        DOM.h3("⚙️ Simulation Params", style="font-weight: 700; margin-top: 0; color: #818cf8; margin-bottom: 0.5rem;"),
                        DOM.p("Steps: $(steps) | dt: $(dt) | σ: $(sigma)", style="color: #cbd5e1; margin-bottom: 0.25rem; font-family: monospace;"),
                        DOM.p("StableRNG Seed: $(seed)", style="color: #38bdf8; font-weight: bold; font-family: monospace; margin-bottom: 0.5rem;"),
                        DOM.p("The trajectory color transitions from purple/blue (start) to yellow/red (end), representing temporal progression.", style="color: #94a3b8; font-size: 0.9rem; margin: 0; line-height: 1.4;")
                    )
                ),
                
                # Footer
                DOM.div(
                    "Generated with Julia, WGLMakie.jl, and Bonito.jl",
                    style = "margin-top: 3rem; color: #475569; font-size: 0.85rem; font-weight: 500;"
                )
            )
        end
    end
end

# 3. Main CLI Entry Point
function main(args = ARGS)
    println("Starting 3D Brownian Motion Simulation Package...")
    
    # Set default parameters
    steps = 1000
    dt = 0.1
    sigma = 1.5
    seed = 42
    
    # Parse seed from arguments
    for arg in args
        parsed_seed = tryparse(Int, arg)
        if !isnothing(parsed_seed)
            seed = parsed_seed
            println("Using command-line provided seed: $seed")
            break
        end
    end
    
    # Build the app with current params
    app = build_app(steps, dt, sigma, seed)
    
    if "serve" in args
        println("Starting live interactive server on http://127.0.0.1:8081 ...")
        server = Bonito.Server(app, "127.0.0.1", 8081)
        try
            wait(server)
        catch e
            if e isa InterruptException
                println("\n\nShutting down server gracefully...")
            else
                rethrow(e)
            end
        finally
            close(server)
        end
    else
        println("Exporting app to static HTML 'index.html'...")
        Bonito.export_static("index.html", app)
        println("Successfully exported!")
        println("\n💡 TIP: Since opening 'index.html' directly via the file:// protocol")
        println("   can trigger browser CORS / sandbox security policies that block")
        println("   WebGL interactivity, you should run a live Julia server to view it.")
        println("   To run a live interactive server using Julia, simply run:")
        println("   julia --project=. generate_demo.jl serve")
    end
end

# 4. Pkg App entry point
@main

end # module
