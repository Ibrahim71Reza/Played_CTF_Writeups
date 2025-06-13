' ==============================================
' Fixed HTB VBScript Deobfuscator and Solver
' ==============================================

' Main function to handle all deobfuscation
Sub Main()
    On Error Resume Next
    
    ' Phase 1: Extract the regex patterns from the final payload
    Dim regexPatterns(3)
    regexPatterns(0) = "^[MSy][FfK][ERT][yCM][efI][{31][KeN][jIS][Uol][z5j][}TR][DNV][4Qj][kY_][{Qw][Qz9][R{h][UF_][9Ns][l7W][SQI][lPb][9ZQ][QTJ][Y97][Ei3][IKL][x0U][iUX][FOE][QnU][xL8][RT_][lkL][d}q][9Sa]$"
    regexPatterns(1) = "^[{Sp][F7H][R1t][CHG][ze5][1na][D7N][jGJ][U}r][kBj][RSq][ZEN][3WQ][k9q][Kw9][XzV][WkR][FLi][m94][HW2][dQT][r{l][9}t][tpT][B8Y][A13][TI0][M7x][EZU][yFb][Quh][BRx][TsA][kQJ][3Xd][r39]$"
    regexPatterns(2) = "^[WoS][cFe][_yR][CzE][Xce][1HN][OYN][vTj][uDU][MYj][Rr7][GN4][tEQ][8kd][wnr][zpI][5Ra][F2x][9hP][xeW][9JQ][lRF][9ai][j7T][UVY][c3F][enI][fwx][vUH][xXF][Q1{][EVx][5TX][Fki][Zdw][of9]$"
    
    ' Phase 2: Compute the correct Base64 string by intersecting character sets
    Dim correctBase64
    correctBase64 = ComputeCorrectBase64(regexPatterns)
    
    ' Phase 3: Decode the Base64 to get the flag
    Dim flag
    flag = Base64Decode(correctBase64)
    
    ' Display results
    WScript.Echo "Extracted Regex Patterns:"
    For i = 0 To UBound(regexPatterns)
        WScript.Echo "Pattern " & (i+1) & ": " & regexPatterns(i)
    Next
    
    WScript.Echo vbCrLf & "Computed Base64: " & correctBase64
    WScript.Echo "Decoded Flag: " & flag
End Sub

' Computes the correct Base64 by finding intersecting characters
Function ComputeCorrectBase64(patterns)
    Dim result, i, j, charSets, currentChar
    Dim patternCount : patternCount = 3 ' We have 3 patterns
    
    ' Initialize result as empty string
    result = ""
    
    ' For each character position (1-36)
    For i = 1 To 36
        ' Get the character sets from all patterns for this position
        ReDim charSets(patternCount - 1)
        For j = 0 To patternCount - 1
            charSets(j) = GetCharacterSet(patterns(j), i)
        Next
        
        ' Find the intersection (common character)
        currentChar = FindCommonCharacter(charSets)
        
        ' Build the result string
        result = result & currentChar
    Next
    
    ComputeCorrectBase64 = result
End Function

' Gets a specific character set from a pattern
Function GetCharacterSet(pattern, pos)
    Dim bracketCount, i, charSetStart, charSetEnd
    
    bracketCount = 0
    charSetStart = 0
    charSetEnd = 0
    
    For i = 1 To Len(pattern)
        If Mid(pattern, i, 1) = "[" Then
            bracketCount = bracketCount + 1
            If bracketCount = pos Then
                charSetStart = i + 1
            End If
        ElseIf Mid(pattern, i, 1) = "]" Then
            If bracketCount = pos Then
                charSetEnd = i - 1
                Exit For
            End If
        End If
    Next
    
    If charSetStart > 0 And charSetEnd > 0 Then
        GetCharacterSet = Mid(pattern, charSetStart, charSetEnd - charSetStart + 1)
    Else
        GetCharacterSet = ""
    End If
End Function

' Finds the common character across multiple sets
Function FindCommonCharacter(sets)
    Dim i, j, commonChars, currentSet
    
    ' Start with all characters from first set
    commonChars = sets(0)
    
    ' Intersect with each subsequent set
    For i = 1 To UBound(sets)
        currentSet = sets(i)
        commonChars = IntersectStrings(commonChars, currentSet)
        
        ' If no intersection, return first character from first set
        If Len(commonChars) = 0 Then
            FindCommonCharacter = Left(sets(0), 1)
            Exit Function
        End If
    Next
    
    ' Return first common character
    FindCommonCharacter = Left(commonChars, 1)
End Function

' Returns intersection of two strings (common characters)
Function IntersectStrings(s1, s2)
    Dim result, i, c
    result = ""
    
    For i = 1 To Len(s1)
        c = Mid(s1, i, 1)
        If InStr(s2, c) > 0 Then
            result = result & c
        End If
    Next
    
    IntersectStrings = result
End Function

' Base64 decoding function for VBScript
Function Base64Decode(base64)
    On Error Resume Next
    Dim xml, el
    Set xml = CreateObject("MSXML2.DOMDocument")
    Set el = xml.createElement("tmp")
    el.dataType = "bin.base64"
    el.text = base64
    Base64Decode = BytesToString(el.nodeTypedValue)
    If Err.Number <> 0 Then
        WScript.Echo "Base64 decode error: " & Err.Description
        Base64Decode = ""
    End If
End Function

' Helper function to convert bytes to string
Function BytesToString(bytes)
    On Error Resume Next
    Dim stream
    Set stream = CreateObject("ADODB.Stream")
    stream.Type = 1 ' adTypeBinary
    stream.Open
    stream.Write bytes
    stream.Position = 0
    stream.Type = 2 ' adTypeText
    stream.CharSet = "us-ascii"
    BytesToString = stream.ReadText
    stream.Close
    If Err.Number <> 0 Then
        WScript.Echo "Bytes to string error: " & Err.Description
        BytesToString = ""
    End If
End Function

' Run the main function
Main