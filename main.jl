using CSV
using DataFrames
using GLMakie
using Unitful
using LinearAlgebra
using NativeFileDialog

set_theme!(theme_dark())

# Data Observables
timeData = Observable(Float64[])
vXData = Observable(Float64[])
vYData = Observable(Float64[])

fig = Figure(size = (1000, 800))

gsTop = GridLayout(fig[1, 1])
axVX = Axis(gsTop[1, 1], title = "vX", xlabel = "Time (s)", ylabel = "vx (m/s)")
axVY = Axis(gsTop[1, 2], title = "vY", xlabel = "Time (s)", ylabel = "vy (m/s)")

gsBottom = GridLayout(fig[2, 1])
axVector = Axis(gsBottom[1, 1], title = "Momentum Vector Δp", aspect = DataAspect())
axValues = Axis(gsBottom[1, 2])
hidedecorations!(axValues); hidespines!(axValues)

gsControls = GridLayout(gsBottom[1, 3])

loadBtn = Button(gsControls[1, 1], label = "Load CSV")

Label(gsControls[2, 1], "Mass (kg)")

mass_sl = Slider(gsControls[4, 1], range = 0.1:0.1:10.0, startvalue = 0.4, horizontal = false, height=Relative(0.7))
objectMass = mass_sl.value
Label(gsControls[3, 1], lift(x -> "$(round(x, digits=2)) kg", objectMass))

on(loadBtn.clicks) do _
	fileName = pick_file(filterlist="csv")
	if !isempty(fileName)
		try
			df = CSV.read(fileName, DataFrame)
			rename!(
				df,
				names(df)[1] => :t,
				names(df)[4] => :vx,
				names(df)[5] => :vy
			)
			timeData[] = Float64.(df.t)
			vXData[] = Float64.(df.vx)
			vYData[] = Float64.(df.vy)
			autolimits!(axVX)
			autolimits!(axVY)
		catch e
			println("Error loading CSV: $e")
		end
	end
end


limitValue = Observable(2.0)
on(limitValue) do val
	limits!(axVector, -val, val, -val, val)
end

limitValue[] = 2.0

deregister_interaction!(axVX, :rectanglezoom)
deregister_interaction!(axVY, :rectanglezoom)
deregister_interaction!(axVector, :rectanglezoom)
deregister_interaction!(axValues, :rectanglezoom)

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
	times = timeData[]
	vxs = vXData[]
	vys = vYData[]
	
	if isempty(times)
		return Point2f(0, 0)
	end
	
	idx2 = findfirst(x -> x >= tTarget, times)
	
	if isnothing(idx2) return Point2f(vxs[end], vys[end]) end
	if idx2 == 1 return Point2f(vxs[1], vys[1]) end
	
	idx1 = idx2 - 1
	t1, t2 = times[idx1], times[idx2]
	
	if t2 == t1 return Point2f(vxs[idx1], vys[idx1]) end
	
	frac = (tTarget - t1) / (t2 - t1)
	
	vx = vxs[idx1] + frac * (vxs[idx2] - vxs[idx1])
	vy = vys[idx1] + frac * (vys[idx2] - vys[idx1])
	
	return Point2f(vx, vy)
end

function updatePhysics(ts, te)
	dt = abs(te - ts)
	
	vBefore = interpolateV(ts)
	vAfter = interpolateV(te)
	
	dp = objectMass[] .* (vAfter - vBefore)
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

on(objectMass) do _
	if !isnan(tStart[]) && !isnan(tEnd[])
		updatePhysics(tStart[], tEnd[])
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
