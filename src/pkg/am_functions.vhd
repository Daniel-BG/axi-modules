package am_functions is
	--headers
	function am_minval(a, b: integer) return integer;
	function am_maxval(a, b: integer) return integer;
	function am_unsignedlen(invalue: integer; is_signed: boolean) return integer;
	
end am_functions;

package body am_functions is
	--actual function bodies
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

    function am_unsignedlen(invalue: integer; is_signed: boolean) return integer is
    begin
        if is_signed then
            return invalue + 1;
        else
            return invalue;
        end if;
    end function;
end am_functions;