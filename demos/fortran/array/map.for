subroutine T_array_map
	implicit none
	integer, dimension(2, 3)::a
	integer, dimension(2, 3)::a2
	logical, dimension(2, 3)::logi
	a = reshape((/ 1, 2, 3, 4, 5, 6 /), (/ 2, 3 /))
	a2 = reshape((/ 8, 9, 0, 1, 2, 3 /), (/ 2, 3 /))
	logi = reshape((/ .FALSE., .TRUE., .TRUE., .TRUE., .TRUE., .FALSE. /), (/ 2, 3 /))

end subroutine