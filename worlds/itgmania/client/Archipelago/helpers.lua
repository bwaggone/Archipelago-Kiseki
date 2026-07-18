local AP = ...

AP.FormatNotificationName = function(name)
	if not name then return "Unknown" end
	if name:find("/") then
		local parts = {}
		for part in name:gmatch("[^/]+") do
			table.insert(parts, part)
		end
		if #parts >= 2 then
			return parts[2]
		elseif #parts == 1 then
			return parts[1]
		end
	end
	return name
end

AP.CreateRequest = function(event, data)
	return JsonEncode({
		event=event,
		data=data
	})
end
