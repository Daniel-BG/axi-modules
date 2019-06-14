package am_functions is
	--headers
	--function bits(invalue: integer) return integer;
	function am_minval(a, b: integer) return integer;
	function am_maxval(a, b: integer) return integer;
	--function sum(a: integer_vector) return integer;
	--function partsum(a: integer_vector; numelems: integer) return integer;
	function am_unsignedlen(invalue: integer; is_signed: boolean) return integer;
	
end am_functions;

package body am_functions is
--	--actual function bodies
--	function bits(invalue: integer) return integer is
--		variable i: integer := 1;
--	begin
--		while i <= 32 loop
--			if invalue <= 2**i - 1 then
--				return i;
--			end if;
--			i := i + 1;
--		end loop;
--		return -1;
--	end function;

	function am_minval(a, b: integer) return integer is
	begin
		if a > b then
			return b;
		else
			return a;
		end if;
	end function;

	function am_maxval(a, b: integer) return integer is
	begin
		if a > b then
			return a;
		else
			return b;
		end if;
	end function;

--	function sum(a: integer_vector) return integer is
--		variable res: integer := 0;
--	begin
--		for i in a'low to a'high loop
--			res := res + a(i);
--		end loop;
--		return res;
--	end function;
	
--	function partsum(a: integer_vector; numelems: integer) return integer is
--		variable res: integer := 0;
--	begin
--		for i in a'low to a'low + numelems - 1 loop
--			res := res + a(i);
--		end loop;
--		return res;
--	end function;

    function am_unsignedlen(invalue: integer; is_signed: boolean) return integer is
    begin
        if is_signed then
            return invalue + 1;
        else
            return invalue;
        end if;
    end function;
end am_functions;