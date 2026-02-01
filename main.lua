local folders = {};
local checked = {};

local function folder(path)
	if folders[path] then return end
	makefolder(path);
	folders[path] = true;
end

local function dump(instance, path, counts)
	if checked[instance] then return end
	checked[instance] = 1;
	counts = counts or {};
	local name = instance.Name:gsub('[<>:"/\\|%?%*]', '_');
	counts[name] = (counts[name] or 0) + 1;
	if counts[name] > 1 then name = name .. counts[name] end
	
	local classname = instance.ClassName;
	local script = classname == "LocalScript" or classname == "Script" or classname == "ModuleScript";
	local remote = classname == "RemoteEvent" or classname == "RemoteFunction" or classname == "BindableEvent" or classname == "BindableFunction";
	if script then
		local source;
		local s, r = pcall(function() return instance.Source end);
		if s and r and r ~= "" then source = r end
		if not source and decompile then
			s, r = pcall(decompile, instance);
			if s and r and r ~= "" then source = r end
		end
		
		if source then
			local fulname = instance:GetFullName();
			local parts = fulname:split(".");
			local pathLine = "game:GetService(\"" .. parts[1] .. "\")";
			for i = 2, #parts do
				pathLine = pathLine .. "." .. parts[i];
			end

			source = "-- " .. pathLine .. "\n\n" .. source;

			folder(path);
			writefile(path .. name .. ".lua", source);
			task.wait();
		end
	elseif remote then
		folder(path);
		local method = "FireServer";
		if classname == "RemoteFunction" then method = "InvokeServer" end
		if classname == "BindableEvent" then method = "Fire" end
		if classname == "BindableFunction" then method = "Invoke" end
		local full = instance:GetFullName();
		local parts = full:split(".");
		local line = "game:GetService(\"" .. parts[1] .. "\")";
		for i = 2, #parts do
			line = line .. ":WaitForChild(\"" .. parts[i] .. "\")";
		end
		line = line .. ":" .. method .. "()";
		writefile(path .. name .. ".remote", line);
	end
	
	local children = instance:GetChildren();
	if #children == 0 then return end
	local childcounts = {};
	local nextpath = path .. name .. "/";
	if script or remote then nextpath = path .. name .. " children/" end
	for _, child in pairs(children) do
		dump(child, nextpath, childcounts);
	end
end

for _, service in pairs({
	game:GetService("ReplicatedFirst"),
	game:GetService("ReplicatedStorage"),
	game:GetService("Players"),
	game:GetService("StarterPlayer")
}) do
	local rootpath =
		game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
			:gsub("[^%w%s%-]", "")
			:gsub("%s+", " ")
			:gsub("%s+$", "")
		.. "@dumped/" .. service.Name .. "/";

	local rootcounts = {};
	for _, child in pairs(service:GetChildren()) do
		dump(child, rootpath, rootcounts);
	end
end

print("dumped")
