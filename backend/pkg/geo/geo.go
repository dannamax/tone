package geo

import "math"

func HaversineDistance(lat1, lng1, lat2, lng2 float64) float64 {
	const R = 6371000.0

	dLat := (lat2 - lat1) * math.Pi / 180.0
	dLng := (lng2 - lng1) * math.Pi / 180.0
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*math.Pi/180.0)*math.Cos(lat2*math.Pi/180.0)*
			math.Sin(dLng/2)*math.Sin(dLng/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
	return R * c
}

func IsWithinRadius(targetLat, targetLng, submitLat, submitLng float64, radiusMeters int) bool {
	distance := HaversineDistance(targetLat, targetLng, submitLat, submitLng)
	return distance <= float64(radiusMeters)
}
