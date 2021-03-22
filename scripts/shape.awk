#!/usr/bin/awk
# DS:SHAPE
#
# NAME
#       ds:shape, shape.awk
#
# SYNOPSIS
#       ds:shape [-h|file*] [patterns] [fields] [chart_size=15ln] [awkargs]
#
# DESCRIPTION
#       shape.awk is a script to print the general shape of text-based data.
#
#       To run the script, ensure AWK is installed and in your path (on most Unix-based 
#       systems it should be), and call it on a file:
#
#          > awk -f shape.awk -v measures=[patterns] -v fields=[fields] file
#
#       ds:shape is the caller function for the shape.awk script. To run any of the examples 
#       below, map AWK args as given in SYNOPSIS.
#
#       When running with piped data, args are shifted:
#
#          $ data_in | ds:shape [patterns] [fields] [chart=t] [chart_size=15ln] [awkargs]
#
# FIELD CONSIDERATIONS
#       When running ds:pow, an attempt is made to infer field separators of up to
#       three characters. If none found, FS will be set to default value, a single
#       space = " ". To override FS, add as a trailing awkarg. If the two files have
#       different FS, assign to vars fs1 and fs2. Be sure to escape and quote if needed. 
#       AWK's extended regex can be used as FS:
#
#          $ ds:shape file searchtext 2,3 t 15 -v fs1=',' -v fs2=':'
#
#          $ ds:shape file searchtext 2,3 t 15 -v FS=" {2,}"
#
#          $ ds:shape file searchtext 2,3 t 15 -F'\\\|'
#
#       If FS is set to an empty string, all characters will be separated.
#
#          $ ds:shape file searchtext 2,3 t 15 -v FS=""
#
# USAGE
#   -h  Print this help.
#
#       If no patterns or fields are provided, ds:shape will test each line for length,
#       and generate statistics and a graphic from the findings. If only a single pattern 
#       is provided, each line will be searched for the pattern.
#
#          lines - total lines in source file
#          lines with [measure] - lines matching pattern or with length
#          occurrence - total counts of pattern (or chars with length)
#          average - occurrences / total lines
#          approx var - crude occurrence variance
#
#       The distribution chart shows gives a representation of the total number of
#       occurrences per bucket. By default there are 15 buckets - to run with custom 
#       [n] buckets set [chart_size] = [n].
#
#       Distribution chart is produced by default, to turn off set [chart_size] = 0
#
#       Separate [fields] with commas. Setting a field != 0 will limit the scope of 
#       measure tests to that field. Each field provided will generate a new chart set.
#
#       [patterns] (measures) can be any regex. Separate patterns with a comma. For easy 
#       comparison each pattern will create a new chart on the same set of lines as 
#       the first.
#
#       Depending on the output space, up to 10 patterns can be displayed per field 
#       section.
#
# AWKARG OPTS
#       To set a custom pattern for the shape chart, set shape_marker to any string:
#
#          -v shape_marker=.
#
#       By default the shape marker pattern is "+".
#
# VERSION
#       1.0
#
# AUTHORS
#       Tom Hall (tomhallmain@gmail.com)

BEGIN {
  if (!tty_size) tty_size = 100
  lineno_size = Max(length(lines), 5)
  buffer_str = "                        "
  output_space = tty_size - lineno_size - 2
  if (!span) span = 15

  if (!measures) measures = "_length_"
  SetMeasures(measures, MeasureSet, MeasureTypes)

  if (!fields) fields = "0"
  split(fields, Fields, ",")
  for (f in Fields) {
    field = Fields[f]
    if (field != "0" && field + 0 == 0) {
      delete Fields[f]
    }
  }
  if (!length(Fields)) {
    Fields[1] = "0"
  }

  if (shape_marker) {
    marker_len = length(shape_marker)
    marker_len_mod = marker_len > 1 ? tty_size / marker_len : tty_size
    for (i = 1; i <= marker_len_mod; i++)
      shape_marker_string = shape_marker_string shape_marker
  }
  else
    for (i = 1; i <= tty_size; i++)
      shape_marker_string = shape_marker_string "+"

  measures_len = length(MeasureSet)
  fields_len = length(Fields)
}

{
  bucket_discriminant = NR % span
  if (bucket_discriminant == 0) buckets++

  for (f_i = 1; f_i <= fields_len; f_i++) {
    for (m_i = 1; m_i <= measures_len; m_i++) {
      key = f_i SUBSEP m_i
      field = Fields[f_i]
      measure = MeasureSet[m_i]

      value = MeasureTypes[m_i] ? split($Fields[f_i], Tmp, measure) - 1 : length($field)
      occurrences = Max(value, 0)

      if (occurrences > MaxOccurrences[key]) MaxOccurrences[key] = occurrences
      TotalOccurrences[key] += occurrences
      m = Max(Measure(MeasureTypes[m_i], field, occurrences), 0)
      J[key] += m
      if (m) MatchLines[key]++

      if (bucket_discriminant == 0) {
        if (J[key] > MaxJ[key]) MaxJ[key] = J[key]
        _[key, NR/span] = J[key]
        J[key] = 0
      }
    }
  }
}

END {
  for (f_i = 1; f_i <= fields_len; f_i++) {
    for (m_i = 1; m_i <= measures_len; m_i++) {
      key = f_i SUBSEP m_i

      if (bucket_discriminant) {
        J[key] = J[key] / bucket_discriminant * span
        if (J[key] > MaxJ[key]) MaxJ[key] = J[key]
        l = (NR - J[key] + span) / span
        _[f_i, m_i, l] = J[f_i, m_i]
      }

      AvgOccurrences[key] = TotalOccurrences[key] / NR
      if (MaxJ[key]) match_found = 1
    }
  }

  if (!match_found) {
    print "Data not found with given parameters"
    exit
  }

  output_column_len = int(output_space / measures_len)
  output_column_len_1 = output_column_len + lineno_size + 2
  column_fmt = "%-"output_column_len"s"

  PrintLineNoBuffer()
  print "lines: "NR

  for (f_i = 1; f_i <= fields_len; f_i++) {
    field = Fields[f_i]
    if (fields_len > 1 || field) {
      PrintLineNoBuffer()
      print "stats from field: $"field
    }

    PrintLineNoBuffer()
    for (m_i = 1; m_i <= measures_len; m_i++)
      PrintColumnVal("lines with \""MeasureSet[m_i]"\": "MatchLines[f_i, m_i])
    print ""

    PrintLineNoBuffer()
    for (m_i = 1; m_i <= measures_len; m_i++)
      PrintColumnVal("occurrence: "TotalOccurrences[f_i, m_i])
    print ""

    PrintLineNoBuffer()
    for (m_i = 1; m_i <= measures_len; m_i++)
      PrintColumnVal("average: "AvgOccurrences[f_i, m_i])
    print ""

    if (!simple) {
      PrintLineNoBuffer()
      for (m_i = 1; m_i <= measures_len; m_i++) {
        key = f_i SUBSEP m_i
        PrintColumnVal("approx var: "(MaxOccurrences[key]-AvgOccurrences[key])**2)
      }
      print ""

      printf "%"lineno_size"s ", "lineno"

      for (m_i = 1; m_i <= measures_len; m_i++) {
        key = f_i SUBSEP m_i
        ModJ[key] = MaxJ[key] <= output_column_len ? 1 : output_column_len / MaxJ[key]
      }

      for (m_i = 1; m_i <= measures_len; m_i++) {
        measure_desc = MeasureTypes[m_i] ? "\""MeasureSet[m_i]"\"" : "length"
        PrintColumnVal("distribution of "measure_desc)
      }
      print ""

      buckets++

      for (i = 1; i <= buckets; i++) {
        printf " %"lineno_size"s ", i * span

        for (m_i = 1; m_i <= measures_len; m_i++) {
          key = f_i SUBSEP m_i
          shape_marker = sprintf("%.*s", _[key, i] * ModJ[key], shape_marker_string)
          PrintColumnVal(shape_marker)
        }

        print ""
      }
    }
  }
}

function SetMeasures(measures, MeasureSet, MeasureTypes) {
  split(measures, MeasureSet, ",")
  for (i = 1; i <= length(MeasureSet); i++) {
    measure = MeasureSet[i]
    if ("_length_" ~ "^"measure) {
      MeasureSet[i] = "length"
      MeasureTypes[i] = 0
    }
    else {
      MeasureTypes[i] = 1
    }
  }
}

function Measure(measure, field, occurrences) {
  if (measure) {
    if (measure == 1) return occurrences
  }
  else return length($field)
}

function PrintLineNoBuffer() {
  if (simple) return
  printf "%.*s", lineno_size + 2, buffer_str
}

function PrintColumnVal(print_string) {
  printf column_fmt, print_string
}

