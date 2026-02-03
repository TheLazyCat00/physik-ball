using CSV
using DataFrames
using GLMakie
using Unitful
using LinearAlgebra

set_theme!(theme_dark())

# Globale Variable für PackageCompiler (falls nötig)
const DISPLAY_WINDOW_CLOSED_CONDITION = Condition()

function main_logic(csvPath::String)
    df = CSV.read(csvPath, DataFrame)

    rename!(
        df,
        Dict(
            "Video-Auswertung: Zeit (s)" => :t,
            "Video-Auswertung: X-Geschwindigkeit (m/s)" => :vx,
            "Video-Auswertung: Y-Geschwindigkeit (m/s)" => :vy
        ))

    timeData = Float64.(df.t)
    vXData = Float64.(df.vx)
    vYData = Float64.(df.vy)

    fig = Figure(size = (800, 800))

    # Event handling to notify when window closes (important for compiled app)
    on(events(fig).window_open) do open
        if !open
            notify(DISPLAY_WINDOW_CLOSED_CONDITION)
        end
    end

    axVX = Axis(
        fig[1:2, 1],
        title = "vX",
        xlabel = "Zeit (s)",
        ylabel = "vx (m/s)")

    axVY = Axis(
        fig[1:2, 2],
        title = "vY",
        xlabel = "Zeit (s)",
        ylabel = "vy (m/s)")

    axVector = Axis(
        fig[3:4, 1],
        title = "Impulsvektor Δp",
        aspect = DataAspect())

    axValues = Axis(
        fig[3:4, 2])

    hidedecorations!(axValues)
    hidespines!(axValues)

    limitValue = Observable(2.0)
    on(limitValue) do val
        limits!(axVector, -val, val, -val, val)
    end

    limitValue[] = 2.0

    deregister_interaction!(axVX, :rectanglezoom)
    deregister_interaction!(axVY, :rectanglezoom)

    lines!(axVX, timeData, vXData, color = :cyan)
    lines!(axVY, timeData, vYData, color = :magenta)
    hlines!(axVector, [0], color = :white, alpha = 0.1)
    vlines!(axVector, [0], color = :white, alpha = 0.1)

    tStart = Observable(NaN)
    tEnd = Observable(NaN)

    for ax in [axVX, axVY]
        vlines!(ax, tStart, color = :springgreen, linestyle = :dash)
        vlines!(ax, tEnd, color = :tomato, linestyle = :dash)
    end

    arrowPos = Observable([Point2f(0, 0)])
    arrowDir = Observable([Point2f(0, 0)])

    Makie.arrows2d!(
        axVector,
        arrowPos,
        arrowDir,
        color = :yellow,
        shaftwidth = 2,
        markerspace = :pixel)

    magValueText = Observable("Δp: 0.000 kg*m/s")
    forceValueText = Observable("F: 0.0 N")

    text!(
        axValues, 0.1, 0.6,
        text = magValueText,
        color = :gray70,
        fontsize = 28,
        align = (:left, :center),
        space = :relative)

    text!(
        axValues, 0.1, 0.4,
        text = forceValueText,
        color = :orange,
        fontsize = 28,
        align = (:left, :center),
        space = :relative)

    isDragging = Observable(false)

    function interpolateV(tTarget)
        idx2 = findfirst(x -> x >= tTarget, timeData)
        
        if isnothing(idx2) return Point2f(vXData[end], vYData[end]) end
        if idx2 == 1 return Point2f(vXData[1], vYData[1]) end
        
        idx1 = idx2 - 1
        t1, t2 = timeData[idx1], timeData[idx2]
        
        frac = (tTarget - t1) / (t2 - t1)
        
        vx = vXData[idx1] + frac * (vXData[idx2] - vXData[idx1])
        vy = vYData[idx1] + frac * (vYData[idx2] - vYData[idx1])
        
        return Point2f(vx, vy)
    end

    function updatePhysics(ts, te)
        dt = abs(te - ts)
        
        vVor = interpolateV(ts)
        vNach = interpolateV(te)
        
        dp = ballMass .* (vNach - vVor)
        mag = norm(dp)
        fAvg = dt > 0 ? mag / dt : 0.0
        
        arrowDir[] = [Point2f(dp[1], dp[2])]
        magValueText[] = "Δp: $(round(mag, digits=3)) kg*m/s"
        forceValueText[] = "F: $(round(fAvg, digits=1)) N"
        
        maxVal = max(abs(dp[1]), abs(dp[2]), mag)
        if maxVal > limitValue[]
            limitValue[] = maxVal * 1.3
        end
    end

    on(events(axVX.scene).mousebutton) do event
        if event.button == Mouse.left
            if event.action == Mouse.press
                pos = mouseposition(axVX.scene)
                tStart[] = pos[1]
                tEnd[] = pos[1]
                isDragging[] = true
            elseif event.action == Mouse.release
                isDragging[] = false
                updatePhysics(tStart[], tEnd[])
            end
        end
    end

    on(events(axVX.scene).mouseposition) do pos
        if isDragging[]
            axPos = mouseposition(axVX.scene)
            tEnd[] = axPos[1]
            updatePhysics(tStart[], tEnd[])
        end
    end

    display(fig)
end

# Entry Point für PackageCompiler
function julia_main()::Cint
    try
        global ballMass = length(ARGS) >= 1 ? parse(Float64, ARGS[1]) : 0.4
        local csvPath = length(ARGS) >= 2 ? ARGS[2] : "Physik_Kopfball.csv"

        if !isfile(csvPath)
             println(stderr, "Error: CSV file '$csvPath' not found.")
             return 1
        end

        main_logic(csvPath) 
        
        # Wait for window close signal (needed for standalone app to stay open)
        if isdefined(Base, :active_repl)
             # In REPL, do nothing
        else
             wait(DISPLAY_WINDOW_CLOSED_CONDITION)
        end
        
        return 0
    catch e
        @error "Error in application" exception=(e, catch_backtrace())
        return 1
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    # Skript-Modus
    global ballMass = length(ARGS) >= 1 ? parse(Float64, ARGS[1]) : 0.4
    csv = length(ARGS) >= 2 ? ARGS[2] : "Physik_Kopfball.csv"
    if !isfile(csv)
        println(stderr, "Error: CSV file '$csv' not found.")
        exit(1)
    end
    main_logic(csv)
    # Im Skript-Modus wartet Julia automatisch, wenn GLMakie offen ist (meistens)
    # aber sicherheitshalber:
    wait(DISPLAY_WINDOW_CLOSED_CONDITION)
end
