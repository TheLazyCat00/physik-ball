using CSV
using DataFrames
using GLMakie
using Unitful
using LinearAlgebra

set_theme!(theme_dark())

df = CSV.read(
	"Physik_Kopfball.csv", DataFrame)
const ballMass = 0.4

rename!(
	df, Dict(
	"Video-Auswertung: Zeit (s)" => :t,
	"Video-Auswertung: X-Geschwindigkeit (m/s)" => :vx,
	"Video-Auswertung: Y-Geschwindigkeit (m/s)" => :vy))

timeData = Float64.(df.t)
vXData = Float64.(df.vx)
vYData = Float64.(df.vy)

fig = Figure(
	size = (1200, 800))

axVX = Axis(
	fig[1, 1], title = "vX: Klicken & Ziehen",
	xlabel = "Zeit (s)", ylabel = "vx (m/s)")
axVY = Axis(
	fig[1, 2], title = "vY",
	xlabel = "Zeit (s)", ylabel = "vy (m/s)")

limitValue = Observable(2.0)
axVector = Axis(
	fig[2, 1], title = "Echtzeit Impulsvektor Δp",
	xlabel = "Δpx (kg*m/s)", ylabel = "Δpy (kg*m/s)",
	aspect = DataAspect())

# Die Magnitude-Achse (jetzt ohne ungültige Attribute)
axMag = Axis(
	fig[2, 2], title = "Magnitude")

# Alles Verstecken über Funktionen statt Attribute
hidedecorations!(axMag) # Versteckt Ticks, Labels, Grids
hidespines!(axMag)      # Versteckt die Rahmenlinien

on(limitValue) do val
	limits!(axVector, -val, val, -val, val)
end
limitValue[] = 2.0

deregister_interaction!(axVX, :rectanglezoom)
deregister_interaction!(axVY, :rectanglezoom)
deregister_interaction!(axVector, :rectanglezoom)

lines!(axVX, timeData, vXData, color = :cyan)
lines!(axVY, timeData, vYData, color = :magenta)
hlines!(axVector, [0], color = :white, alpha = 0.2)
vlines!(axVector, [0], color = :white, alpha = 0.2)

tStart = Observable(NaN)
tEnd = Observable(NaN)

vlines!(axVX, tStart, color = :springgreen, linestyle = :dash)
vlines!(axVX, tEnd, color = :tomato, linestyle = :dash)
vlines!(axVY, tStart, color = :springgreen, linestyle = :dash)
vlines!(axVY, tEnd, color = :tomato, linestyle = :dash)

arrowPos = Observable([Point2f(0, 0)])
arrowDir = Observable([Point2f(0, 0)])

Makie.arrows2d!(
	axVector, arrowPos, arrowDir,
	color = :yellow, shaftwidth = 4.0,
	tiplength = 0.2, tipwidth = 0.2)

lines!(
	axVector, lift(d -> [Point2f(0, 0), Point2f(0, norm(d[1]))], arrowDir),
	color = (:white, 0.4), linewidth = 8)

magValueText = Observable("0.000\nkg*m/s")

# Text im axMag zentrieren
text!(
	axMag, 0.5, 0.5,
	text = magValueText,
	color = :white, fontsize = 45,
	align = (:center, :center),
	space = :relative)

isDragging = Observable(false)

function updateImpulse(ts, te)
	idxS = argmin(abs.(timeData .- ts))
	idxE = argmin(abs.(timeData .- te))
	
	vVor = Point2f(vXData[idxS], vYData[idxS])
	vNach = Point2f(vXData[idxE], vYData[idxE])
	
	deltaP = ballMass .* (vNach - vVor)
	magnitude = norm(deltaP)
	
	arrowDir[] = [Point2f(deltaP[1], deltaP[2])]
	magValueText[] = "$(round(magnitude, digits=3))\nkg*m/s"
	
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

colsize!(fig.layout, 1, Relative(0.8))

display(fig)
