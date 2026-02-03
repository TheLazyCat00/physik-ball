using CSV
using DataFrames
using GLMakie
using Unitful
using LinearAlgebra

set_theme!(theme_dark())

df = CSV.read(
	"Physik_Kopfball.csv", 
	DataFrame)

const ballMass = 0.4

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

fig = Figure(
	size = (1200, 800))

axVX = Axis(
	fig[1, 1], 
	title = "vX: Klicken & Ziehen", 
	xlabel = "Zeit (s)", 
	ylabel = "vx (m/s)")

axVY = Axis(
	fig[1, 2], 
	title = "vY", 
	xlabel = "Zeit (s)", 
	ylabel = "vy (m/s)")

limitValue = Observable(2.0)

axVector = Axis(
	fig[2, 1:2], 
	title = "Echtzeit Impulsvektor Δp",
	xlabel = "Δpx (kg*m/s)", 
	ylabel = "Δpy (kg*m/s)",
	aspect = DataAspect())

on(limitValue) do val
	limits!(axVector, -val, val, -val, val)
end

limitValue[] = 2.0

deregister_interaction!(axVX, :rectanglezoom)
deregister_interaction!(axVY, :rectanglezoom)
deregister_interaction!(axVector, :rectanglezoom)

lines!(axVX, timeData, vXData, color = :cyan)
lines!(axVY, timeData, vYData, color = :magenta)
hlines!(axVector, [0], color = :white, alpha = 0.1)
vlines!(axVector, [0], color = :white, alpha = 0.1)

tStart = Observable(NaN)
tEnd = Observable(NaN)

vlines!(axVX, tStart, color = :springgreen, linestyle = :dash)
vlines!(axVX, tEnd, color = :tomato, linestyle = :dash)
vlines!(axVY, tStart, color = :springgreen, linestyle = :dash)
vlines!(axVY, tEnd, color = :tomato, linestyle = :dash)

arrowPos = Observable([Point2f(0, 0)])
arrowDir = Observable([Point2f(0, 0)])

Makie.arrows2d!(
	axVector, 
	arrowPos, 
	arrowDir,
	color = :yellow, 
	shaftwidth = 2, 
	tiplength = 20, 
	tipwidth = 15, 
	markerspace = :pixel)

magValueText = Observable("0.000")

text!(
	axVector, 
	lift(v -> Point2f(v.widths[1] - 15, v.widths[2] / 2), axVector.scene.viewport),
	text = magValueText,
	color = :gray60, 
	fontsize = 20,
	align = (:right, :center),
	space = :pixel)

text!(
	axVector, 
	lift(v -> Point2f(v.widths[1] - 15, v.widths[2] / 2 - 22), axVector.scene.viewport),
	text = "kg*m/s",
	color = :gray40, 
	fontsize = 11,
	align = (:right, :center),
	space = :pixel)

isDragging = Observable(false)

function updateImpulse(ts, te)
	idxS = argmin(abs.(timeData .- ts))
	idxE = argmin(abs.(timeData .- te))
	
	vVor = Point2f(vXData[idxS], vYData[idxS])
	vNach = Point2f(vXData[idxE], vYData[idxE])
	
	deltaP = ballMass .* (vNach - vVor)
	magnitude = norm(deltaP)
	
	arrowDir[] = [Point2f(deltaP[1], deltaP[2])]
	magValueText[] = "$(round(magnitude, digits=3))"
	
	maxVal = max(abs(deltaP[1]), abs(deltaP[2]), magnitude)
	if maxVal > limitValue[]
		limitValue[] = maxVal * 1.3
	end
	return deltaP
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
			updateImpulse(tStart[], tEnd[])
		end
	end
end

on(events(axVX.scene).mouseposition) do pos
	if isDragging[]
		axPos = mouseposition(axVX.scene)
		tEnd[] = axPos[1]
		updateImpulse(tStart[], tEnd[])
	end
end

display(fig)
