
# dev_scripts

Scripts and CLI commands to make development and data analysis workflows more efficient and expand the capabilities and convenience of your bash or zsh terminal.

All commands are namespaced to `ds:*` so there should be little to no clashing with any existing commands in your local shell environment.


## Installation

### Basic Install

Run the [install.sh](https://github.com/tomhallmain/dev_scripts/blob/master/install.sh) script in the project base directory. If any trouble is encountered running this script, see below manual install instructions.

### Manual Install

To access the utilities in the `commands.sh` file, ensure the below lines are added to your `~/.bashrc` and/or `~/.zshrc` files if using zshell. These files may need to be created.

```bash
DS_LOC=/your/path/to/dev_scripts
source "$DS_LOC/commands.sh"
```

To verify the installation, open a new terminal and run `ds:commands`.

Note that some commands require the default \*nix commands to be overloaded by the GNU coreutils. To set this up using homebrew:

```
$ brew install coreutils
$ echo "export PATH=\"$(brew --prefix coreutils)/libexec/gnubin:/usr/local/bin:$PATH\"" >> ~/.zshrc # OR ~/.bashrc if using bash
```


## Usage and Selected Functions

Once installed, start a bash or zsh session and run `ds:commands` to see available commands, associated aliases and usage patterns.

The below functions are especially useful when working in the terminal, and can be applied to many general situations.

#### `ds:fit`

Fits tabular data (including multibyte characters) dynamically into your terminal, and attempts to format it richly and intelligently as requested by the user. If the max field lengths for all fields combined is too long, the longest fields will be right-truncated until the terminal width is reached.

Also supports file sets as arguments to a single call for quickly reporting on sets of files.

```
$ head -n5 tests/data/taxables.csv
"Index", "Item", "Cost", "Tax", "Total"
1, "Fruit of the Loom Girl's Socks", 7.97, 0.60, 8.57
2, "Rawlings Little League Baseball", 2.97, 0.22, 3.19
3, "Secret Antiperspirant", 1.29, 0.10, 1.39
4, "Deadpool DVD",    14.96, 1.12, 16.08

$ head -n5 tests/data/taxables.csv | ds:fit -v gridlines=1
┌─────┬─────────────────────────────────┬───────┬──────┬───────┐
│Index│  Item                           │   Cost│   Tax│  Total│
├─────┼─────────────────────────────────┼───────┼──────┼───────┤
│    1│  Fruit of the Loom Girl's Socks │   7.97│  0.60│   8.57│
├─────┼─────────────────────────────────┼───────┼──────┼───────┤
│    2│  Rawlings Little League Baseball│   2.97│  0.22│   3.19│
├─────┼─────────────────────────────────┼───────┼──────┼───────┤
│    3│  Secret Antiperspirant          │   1.29│  0.10│   1.39│
├─────┼─────────────────────────────────┼───────┼──────┼───────┤
│    4│  Deadpool DVD                   │  14.96│  1.12│  16.08│
└─────┴─────────────────────────────────┴───────┴──────┴───────┘

$ ds:fit $(fd -e csv) # Fit all CSVs in current dir with fd
```

#### `ds:reo`

Select, reorder, slice data using inferred field separators. Supports expression evaluation, regex searches, exclusions, and/or logic, frame expressions, reversals, and more. Runs ds:fit on output if to a terminal.

Also supports file sets as arguments to a single call for quickly reporting on sets of files.

```bash
$ head -n5 tests/data/company_funding_data.csv
permalink,company,numEmps,category,city,state,fundedDate,raisedAmt,raisedCurrency,round
lifelock,LifeLock,,web,Tempe,AZ,1-May-07,6850000,USD,b
lifelock,LifeLock,,web,Tempe,AZ,1-Oct-06,6000000,USD,a
lifelock,LifeLock,,web,Tempe,AZ,1-Jan-08,25000000,USD,c
mycityfaces,MyCityFaces,7,web,Scottsdale,AZ,1-Jan-08,50000,USD,seed

$ wc -l tests/data/company_funding_data.csv
1460 tests/data/company_funding_data.csv

$ ds:reo tests/data/company_funding_data.csv '1, >200000000' '[^c, [^r'
company   category  city       raisedAmt  raisedCurrency  round
Facebook  web       Palo Alto  300000000  USD             c
ZeniMax   web       Rockville  300000000  USD             a

$ ds:reo tests/data/company_funding_data.csv '[lifelock' '[round,[funded'
b  1-May-07
a  1-Oct-06
c  1-Jan-08

$ ds:reo tests/data/company_funding_data.csv '~Jan-08 && NR<6, 3..1' '[company,~Jan-08'
LifeLock     1-Jan-08
MyCityFaces  1-Jan-08
LifeLock     1-Oct-06
LifeLock     1-May-07
company      fundedDate
```

If your awk version supports it, multibyte characters are supported by `ds:fit` and `ds:reo`.

```bash
$ head -n4 tests/data/emoji
Generating_code_base10 emoji init_awk_len len_simple_extract len_remaining
9193 ⏩ 3 1 2
Generating_code_base10 emoji init_awk_len len_simple_extract len_remaining
9194 ⏪ 3 1 2

$ ds:reo tests/data/emoji '1, NR%2 && NR>80 && NR<90' '[emoji,others'
emoji  Generating_code_base10  init_awk_len  len_simple_extract  len_remaining
❎     10062                              3                   1              2
🚧     unknown                            4                   1              3
❓     10067                              3                   1              2
❔     10068                              3                   1              2
```

#### `ds:join`

Join data on multi-key sets or perform full merges of data. Runs ds:fit on output if to a terminal.

```bash
$ for i in /tmp/jn_a /tmp/jn_b; do echo $i; cat $i; done
/tmp/jn_a
a b c d
1 2 3 4
/tmp/jn_b
a b c d
1 3 2 4

$ ds:join /tmp/jn_a /tmp/jn_b inner 1,4
a  b  c  d  b  c
1  2  3  4  3  2

$ ds:join /tmp/jn_a /tmp/jn_b right 1,2,3,4 1,3,2,4
a  c  b  d
1  2  3  4

$ ds:join /tmp/jn_a /tmp/jn_b outer merge -v verbose=1
BOTH       a  b  c  d
/tmp/jn_b  1  3  2  4
/tmp/jn_a  1  2  3  4
```

#### `ds:pivot`

Pivot tabular data. Runs ds:fit on output if to a terminal.

```bash
$ ds:pivot /tmp/jn_a 1,2 4 3
PIVOT     4  d
1      2  3
a      b     c
```

#### `ds:agg`

Aggregate data by specific indices or by full rows/columns by field value. For example, count all instances of a regex match, sum number data at each index, or group the results of an operation on one index by unique values from another index.

```bash
$ cat /tmp/agg_ex
a  1  -2  3.0  4
b  0  -3  4.0  1
c  3   6  2.5  4

$ ds:agg /tmp/agg_ex
a      1  -2  3.0  4   6.0
b      0  -3  4.0  1   2.0
c      3   6  2.5  4  15.5
+|all  4   1  9.5  9  23.5

$ ds:agg /tmp/agg_ex '*|all,$4*$3,~b' '+,*'
a  1  -2   3.0   4  -24    -6  ~b
b  0  -3   4.0   1    0   -12   1
c  3   6   2.5   4  180    15   0
+  4   1   9.5   9  156    -3   1
*  3  36  30.0  16    0  1080   0
```

#### `ds:uniq` / `ds:fieldcounts`

Get unique lines or sets of fields with optional counts data. Runs ds:fit on output if to a terminal.

```bash
$ cat /tmp/ex
a:1
a:2
a:1
b:1

$ ds:uniq /tmp/ex
a:1
a:2
b:1

$ ds:fieldcounts /tmp/ex | cat
1 a:2
1 b:1
2 a:1

$ ds:fieldcounts /tmp/ex 2
1  2
3  1
```

#### `ds:subsep`

Split off new fields by a given field subseparator pattern.

```bash
$ ds:reo tests/data/testcrimedata.csv 1..5 1,2
cdatetime    address
1/1/06 0:00  3108 OCCIDENTAL DR
1/1/06 0:00  2082 EXPEDITION WAY
1/1/06 0:00  4 PALEN CT
1/1/06 0:00  22 BECKFORD CT

$ ds:subsep tests/data/testcrimedata.csv '\\/' "" -v apply_to_fields=1 | ds:reo 1..5 1..4
cdatetime              address
        1  1  06 0:00  3108 OCCIDENTAL DR
        1  1  06 0:00  2082 EXPEDITION WAY
        1  1  06 0:00  4 PALEN CT
        1  1  06 0:00  22 BECKFORD CT
```

#### `ds:vi` / `ds:grepvi`

Jump directly into vim at a specified file and/or line based on a pattern.

```bash
$ ds:vi commands
Multiple matches found - select a file:
1  commands.sh
2  support/commands
3  support/commands_utils
4  tests/commands_cov.sh
5  tests/commands_tests.sh
6  tests/commands_variants.sh
7  tests/data/commands
Enter a number from the set of files or a pattern: sh
1  commands.sh
2  tests/commands_cov.sh
3  tests/commands_tests.sh
4  tests/commands_variants.sh
Enter a number from the set of files or a pattern: ^commands

$ ds:vi 'function GetOrSet'
No match found - Did you mean to search with ds:grepvi? (y/n) y
Multiple matches found - select a file:
1  scripts/agg.awk
2  scripts/fit_columns.awk
3  scripts/hist.awk
4  scripts/power.awk
Enter a number from the set of files or a pattern: 2
```


#### `ds:trace`

View or search shell trace output.

```
$ ds:test 't(rue)?' true
$ ds:trace
Press enter to trace last command
+ds:trace:7> eval 'ds:test '\''t(rue)?'\'' true'
+(eval):1> ds:test 't(rue)?' true
+ds:test:1> ds:pipe_open
+ds:pipe_open:1> [ '!' -t 0 ']'
+ds:test:2> [[ "$3" -regex-match t ]]
+ds:test:3> echo true
+ds:test:3> grep -Eq 't(rue)?'
```

#### `ds:git_cross_view`

View the current state of your git branches across all repos.

![](https://github.com/tomhallmain/dev_scripts/blob/master/assets/gcv_ex.png?raw=true)

#### `ds:git_recent` and `ds:git_recent_all`

View most recent commits for current repo or all repos in a colorful way.

![](https://github.com/tomhallmain/dev_scripts/blob/master/assets/gr_gra_ex.png?raw=true)

#### `ds:git_refresh`

Refresh all repos in a given base directory with the newest data.

## Acknowledgements

[wcwidth.awk](https://github.com/ericpruitt/wcwidth.awk) by Eric Pruitt is the library which allows `ds:fit` to support multibyte characters. Many thanks to him for this implementation.

## Issues

To report bugs please contact: tomhall.main@gmail.com
