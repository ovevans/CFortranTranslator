subroutine T_interface_add(do_add)
	interface
		function do_add() result (a)
			integer::a
		end function
	end interface
end subroutine

subroutine T_interface_sub(do_sub)
	interface
		function do_sub() result (b)
			integer::b
		end function
	end interface
end subroutine