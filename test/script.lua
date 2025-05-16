function fromHaxe(tbl) 
	print('Called foo()')
	-- Name, Item, Index
	for i,v in pairs(tbl) do
		if(v[3]) then
			print(i,v[1],v[2][v[3]])
		else
			print(i,v[1],v[2])
		end
	end
    -- print(('Called foo()\n int : %i\n float : %0.f\n str : %s\n array[1] : %s\n map.number : %s\n anon.number : %s'):format(int, float, str,array[1],map.number,anon.number))
    return "Printed " .. #tbl
end
function toHaxe()
	return "This","is","a","Test",{["what"]="fuck",'guh'}
end



print("file script.lua loaded!\n")