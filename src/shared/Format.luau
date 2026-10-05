local Format = {}

-- One suffix per power of 1,000, up to Notg at 1e120. Past Vg (1e63) the names carry on in the same way:
-- Uvg, Dvg ... Novg, then Tg, Utg ... Notg.
local SUFFIXES = {
	"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc",
	"Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg",
	"Uvg", "Dvg", "Tvg", "Qavg", "Qivg", "Sxvg", "Spvg", "Ocvg", "Novg", "Tg",
	"Utg", "Dtg", "Ttg", "Qatg", "Qitg", "Sxtg", "Sptg", "Octg", "Notg",
}

function Format.abbreviate(n: number): string
	if n ~= n or n == math.huge then
		return "MAX"
	end
	n = math.floor(n)
	if n < 1000 then
		return tostring(n)
	end
	local tier = math.floor(math.log10(n) / 3)
	if tier >= #SUFFIXES then
		-- Out of names: 1.23e123 still reads at a glance, a row of 124 digits does not.
		return (string.format("%.2e", n):gsub("e%+", "e"))
	end
	local scaled = n / 10 ^ (tier * 3)
	local pattern = if scaled >= 100 then "%.0f" elseif scaled >= 10 then "%.1f" else "%.2f"
	return string.format(pattern, scaled) .. SUFFIXES[tier + 1]
end

-- A share of 0.25 reads as "+25%". (Not for a mini cannon's strength: that is Format.petPower.)
function Format.percent(bonus: number): string
	return "+" .. Format.abbreviate(bonus * 100 + 0.5) .. "%"
end

-- Damage per second as a mini cannon's strength is written: 129 reads "+129 DPS", 12,900 "+12.9K DPS".
function Format.dps(dps: number): string
	return "+" .. Format.abbreviate(dps + 0.5) .. " DPS"
end

-- How strong a mini cannon (a Config.Pets entry) is, the one way every list writes it: "+129 DPS" for an
-- ordinary one (its own damage per second: its bonus x Config.PetDps, kept on the entry as `dps`), "x3" for a
-- Huge (what it multiplies all tower damage by). The text is whole: add no "power" or "%" after it.
-- A Huge's bonus is infinite, so it must never be written as a number: that would read "+MAX".
function Format.petPower(pet): string
	if pet.huge then
		return "x" .. Format.abbreviate(pet.power or 1)
	end
	return Format.dps(pet.dps or 0)
end

function Format.duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local days = seconds // 86_400
	local hours = seconds % 86_400 // 3_600
	local minutes = seconds % 3_600 // 60
	if days > 0 then
		return `{days}d {hours}h`
	elseif hours > 0 then
		return `{hours}h {minutes}m`
	end
	return string.format("%d:%02d", minutes, seconds % 60)
end

return Format
