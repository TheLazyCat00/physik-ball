using CSV
using DataFrames
using GLMakie
using Unitful
using LinearAlgebra
using NativeFileDialog

set_theme!(theme_dark())

# File selection
fileName = pick_file(filterlist="csv")
if isempty(fileName)
	println("No file selected. Exiting.")
	exit()
end

println("Selected: $fileName")

df = CSV.read(fileName, DataFrame)

fig = Figure(size = (1000, 800))

gsTop = GridLayout(fig[1, 1])
axVX = Axis(gsTop[1, 1], title = "vX", xlabel = "Time (s)", ylabel = "vx (m/s)")
axVY = Axis(gsTop[1, 2], title = "vY", xlabel = "Time (s)", ylabel = "vy (m/s)")

gsBottom = GridLayout(fig[2, 1])
axVector = Axis(gsBottom[1, 1], title = "Momentum Vector Δp", aspect = DataAspect())
axValues = Axis(gsBottom[1, 2])
hidedecorations!(axValues); hidespines!(axValues)

gsControls = GridLayout(gsBottom[1, 3])

Label(gsControls[1, 1], "Mass (kg)")

mass_sl = Slider(gsControls[3, 1], range = 0.1:0.1:10.0, startvalue = 0.4, horizontal = false, height=Relative(0.7))
objectMass = mass_sl.value
Label(gsControls[2, 1], lift(x -> "$(round(x, digits=2)) kg", objectMass))

rename!(
	df,
	names(df)[1] => :t,
	names(df)[4] => :vx,
	names(df)[5] => :vy
)

timeData = Float64.(df.t)
vXData = Float64.(df.vx)
vYData = Float64.(df.vy)


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
