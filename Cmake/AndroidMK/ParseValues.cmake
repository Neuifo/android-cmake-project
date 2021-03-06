SET(PARSE_VALUES_DEBUG OFF)

function(catParam param out_prefix out_param out_suffix)
    SET(catParam_param "${param}")
    SET(catParam_prefix "")
    SET(catParam_suffix "")

    string(FIND "${param}" "$" catParam_prefix_index)
    if(NOT "${catParam_prefix_index}" EQUAL "0")
        string(SUBSTRING "${param}" "0" "${catParam_prefix_index}" catParam_prefix)
        string(SUBSTRING "${param}" "${catParam_prefix_index}" "65536" catParam_param)
    endif()

    string(FIND "${catParam_param}" ")" catParam_suffix_index REVERSE)
    if(NOT "${catParam_suffix_index}" EQUAL "-1")
        math(EXPR catParam_suffix_index "${catParam_suffix_index} + 1")
        string(SUBSTRING "${catParam_param}" "${catParam_suffix_index}" "65536" catParam_suffix)
        string(SUBSTRING "${catParam_param}" "0" "${catParam_suffix_index}" catParam_param)
    endif()

    SET(${out_prefix} ${catParam_prefix} PARENT_SCOPE)
    SET(${out_param} ${catParam_param} PARENT_SCOPE)
    SET(${out_suffix} ${catParam_suffix} PARENT_SCOPE)
endfunction()

#注意不能输入list,否则无法解析
function(parseMakeFileFunc param out)
    if("${param}" MATCHES ".*;.*")
        #list
        foreach(param_one ${param})
            parseMakeFileFunc("${param_one}" tmp_param_one)
            list(APPEND tmp_param "${tmp_param_one}")
        endforeach()
    elseif( "${param}" MATCHES "^\\(.*")
        string(REGEX REPLACE "^\\(" "" param ${param})
        string(REGEX REPLACE "\\)$" "" param ${param})
        parseMakeFileFunc("${param}" tmp_param)
    elseif( "${param}" MATCHES "^\\$\\(strip")
        if(PARSE_VALUES_DEBUG)
            MESSAGE("parseMakeFileFunc: strip = ${param}")
        endif()
        string(REPLACE "$(strip" "" strip_param ${param})
        string(REGEX REPLACE "\\)$" "" strip_param "${strip_param}")
        string(STRIP "${strip_param}" strip_param)
        parseMakeFileFunc("${strip_param}" strip_tmp_param)
        set(tmp_param "${strip_tmp_param}")
    elseif( "${param}" MATCHES "^\\$\\(subst")
        if(PARSE_VALUES_DEBUG)
            MESSAGE("parseMakeFileFunc: subst = ${param}")
        endif()
        string(REPLACE "$(subst" "" subst_param ${param})
        string(REGEX REPLACE "\\)$" "" subst_param "${subst_param}")
        string(REPLACE "," ";" subst_param ${subst_param})

        LIST(GET subst_param 0 subst_param0)
        LIST(GET subst_param 1 subst_param1)
        LIST(GET subst_param 2 subst_param2)

        if(subst_param0)
            parseMakeFileFunc(${subst_param0} subst_param0)
        endif()
        if(subst_param1)
            parseMakeFileFunc(${subst_param1} subst_param1)
        endif()
        if(subst_param2)
            parseMakeFileFunc(${subst_param2} subst_param2)
        endif()

        if(PARSE_VALUES_DEBUG)
            MESSAGE("parseMakeFileFunc: subst_param0 = ${subst_param0}")
            MESSAGE("parseMakeFileFunc: subst_param1 = ${subst_param1}")
            MESSAGE("parseMakeFileFunc: subst_param2 = ${subst_param2}")
        endif()

        string(REPLACE "${subst_param0}" "${subst_param1}" subst_param_tmp "${subst_param2}")
        set(tmp_param "${subst_param_tmp}")
    elseif( "${param}" MATCHES "^\\$\\(filter-out" )

    elseif( "${param}" MATCHES "^\\$\\(filter" )
        if(PARSE_VALUES_DEBUG)
            MESSAGE("parseMakeFileFunc: filter = ${param}")
        endif()
        if( "${param}" MATCHES ".*,.*" )
            string(REPLACE "$(filter" "" filter_param ${param})
            string(REGEX REPLACE "\\)$" "" filter_param "${filter_param}")
            string(REPLACE "," ";" filter_list ${filter_param})
            LIST(GET filter_list 0 filter_param1)
            string(STRIP ${filter_param1} filter_param1)
            LIST(GET filter_list 1 filter_param2)
            string(STRIP ${filter_param2} filter_param2)
            parseMakeFileFunc(${filter_param1} filter_param1)
            parseMakeFileFunc(${filter_param2} filter_param2)
            if( "${filter_param1}" MATCHES ".*${filter_param2}.*")
                SET(tmp_param "${filter_param2}")
            else()
                SET(tmp_param "")
            endif()
        else()
        endif()
    elseif( "${param}" MATCHES "^\\$.*\\)$")
        if(PARSE_VALUES_DEBUG)
            MESSAGE("parseMakeFileFunc: func = ${param}")
        endif()

        string(REGEX REPLACE "^\\$" "" func_param ${param})
        string(REGEX REPLACE "^\\(|\\)$" "" func_param "${func_param}")

        string(STRIP "${func_param}" func_param)

        if("${func_param}" MATCHES "^\\$.*")
            parseMakeFileFunc(${func_param} func_tmp_param)
            SET(tmp_param "${${func_tmp_param}}")
        else()
            string(REGEX REPLACE "\\(|\\)" "" func_param ${func_param})
            parseMakeFileFunc("${${func_param}}" no_func_tmp_param)
            SET(tmp_param "${no_func_tmp_param}")
        endif()
    elseif( "${param}" MATCHES ".*\\$.*")
        if(PARSE_VALUES_DEBUG)
            MESSAGE("parseMakeFileFunc: func_in = ${param}")
        endif()

        catParam("${param}" func_in_prefix func_in_param func_in_suffix)

        if(PARSE_VALUES_DEBUG)
            message("parseMakeFileFunc: func_in_param=${func_in_param}")
            message("parseMakeFileFunc: func_in_prefix=${func_in_prefix}")
            message("parseMakeFileFunc: func_in_suffix=${func_in_suffix}")
        endif()

        parseMakeFileFunc("${func_in_param}" func_in_tmp_param)
        set(tmp_param "${func_in_prefix}${func_in_tmp_param}${func_in_suffix}")
    else()
        if(PARSE_VALUES_DEBUG)
            MESSAGE("parseMakeFileFunc: normal = ${param}")
        endif()
        SET(tmp_param "${param}")
    endif()

    if(PARSE_VALUES_DEBUG)
        MESSAGE("parseMakeFileFunc: ${out} = ${tmp_param}")
    endif()
    SET(${out} ${tmp_param} PARENT_SCOPE)
endfunction()

function(marchBrackets in out)
    set(marchBrackets_str "${in}")
    set(marchBrackets_num "0")
    set(marchBrackets_split "")
    string(LENGTH "${marchBrackets_str}" marchBrackets_length)
    math(EXPR marchBrackets_last_index "${marchBrackets_length} - 1")
    foreach(marchBrackets_index RANGE "${marchBrackets_last_index}" "0")
        string(SUBSTRING "${marchBrackets_str}" "${marchBrackets_index}" "1" marchBrackets_sub)

        if("${marchBrackets_sub}" STREQUAL ")" )
            math(EXPR marchBrackets_num "${marchBrackets_num} + 1")
        elseif("${marchBrackets_sub}" STREQUAL "(" )
            math(EXPR marchBrackets_num "${marchBrackets_num} - 1")
        elseif("${marchBrackets_sub}" STREQUAL " ")
            #判断是否有括号对
            if("${marchBrackets_num}" EQUAL "0" )
                string(SUBSTRING "${marchBrackets_str}" "${marchBrackets_index}" "65536" marchBrackets_tmp_str)
                string(SUBSTRING "${marchBrackets_str}" "0" "${marchBrackets_index}" marchBrackets_str)
                string(STRIP ${marchBrackets_tmp_str} marchBrackets_tmp_str)
                list(INSERT marchBrackets_split "0" "${marchBrackets_tmp_str}")
            endif()
        endif()
    endforeach()

    if(NOT marchBrackets_split)
        set(marchBrackets_split "${in}")
    endif()

    if(marchBrackets_str)
        list(INSERT marchBrackets_split "0" "${marchBrackets_str}")
    endif()

    if (PARSE_VALUES_DEBUG)
        message("marchBrackets_split:${marchBrackets_split}")
    endif ()
    set(${out} "${marchBrackets_split}" PARENT_SCOPE)
endfunction()

function(parseValues line local_key)
    SET(parseValues_valueAppend OFF)
    SET(parseValues_valueQuestion OFF)

    if( "${line}" MATCHES ".*:=.*")
        string(REPLACE ":=" ";" parseValues_line_list "${line}")
    elseif( "${line}" MATCHES ".*\\+=.*")
        string(REPLACE "+=" ";" parseValues_line_list "${line}")
        SET(parseValues_valueAppend ON)
    elseif( "${line}" MATCHES ".*\\?=.*")
        string(REPLACE "?=" ";" parseValues_line_list "${line}")
        SET(parseValues_valueQuestion ON)
    elseif( "${line}" MATCHES ".*=.*")
        string(REPLACE "=" ";" parseValues_line_list "${line}")
    endif()

    list(GET parseValues_line_list 0 parseValues_key)
    string(STRIP "${parseValues_key}" parseValues_key)
    if(parseValues_valueQuestion)
        if(NOT "${${parseValues_key}}" STREQUAL "")
            return()
        endif()
    endif()
    if(PARSE_VALUES_DEBUG)
        message("parseValues: key = ${parseValues_key}")
    endif()


    list(GET parseValues_line_list 1 parseValues_values)
    string(STRIP "${parseValues_values}" parseValues_values)
    # Convert to list
    if(PARSE_VALUES_DEBUG)
        message("parseValues values start = ${parseValues_values}")
    endif()

    if("${parseValues_values}" MATCHES " +" AND "${parseValues_values}" MATCHES "\\$")
        marchBrackets("${parseValues_values}" parseValues_values)
    else()
        string(REGEX REPLACE " +" ";" parseValues_values "${parseValues_values}")
    endif()

    string(REPLACE "-include;" "-include " parseValues_values "${parseValues_values}")

    if(PARSE_VALUES_DEBUG)
        message("parseValues values end = ${parseValues_values}")
    endif()

    SET(${local_key} ${parseValues_key} PARENT_SCOPE)

    if(parseValues_valueAppend)
        LIST(APPEND ${parseValues_key} ${parseValues_values})
    else()
        SET(${parseValues_key} ${parseValues_values})
    endif()

    SET(${parseValues_key} ${${parseValues_key}} PARENT_SCOPE)
endfunction()