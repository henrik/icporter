# ICporter

Exports ICA-banken bank transactions as JSON files on disk.

The exported files can be analyzed with [ICpenses](http://github.com/henrik/icpenses) to provide expense analysis.

Feel free to write your own ICporter-compatible exporters or analyzers.

## Usage

If you don't want to reveal your credentials in the command argument, put them in a file.
The file format is e.g.

    750123-4567  
    1234
    
Set file permissions so only you can read it:

    chmod 700 ~/.ica_credentials

The default path is `~/.ica_credentials`. If you want to use another path, specify this when you export:

    ./icporter.rb --credentials="~/.my_credentials"

Personnummer and PIN are required arguments if you don't provide a credentials file.

Month can be given as e.g. `2010-01` or as `0` for the current month, `1` for last month etc. Default is current month.

Account name or number can be provided. Otherwise it picks the first one.

Output directory defaults to `~/Documents/icpenses/data`. The directory is created if it doesn't exist.

Some examples:

    ./icporter.rb --pnr=750123-4567 --pin=1234 --month=0
    ./icporter.rb --pnr=750123-4567 --pin=1234 --month=-1
    ./icporter.rb --pnr=750123-4567 --pin=1234 --month=2010-01
    ./icporter.rb --pnr=750123-4567 --pin=1234 --account="Betalkort"
    ./icporter.rb --pnr=750123-4567 --pin=1234 --output="/tmp/data"


## TODO

 * Decouple "framework" and ICA-specific code
 * Tidywork

## Credits and license

By [Henrik Nyh](http://henrik.nyh.se/) under the MIT license:

>  Copyright (c) 2010 Henrik Nyh
>
>  Permission is hereby granted, free of charge, to any person obtaining a copy
>  of this software and associated documentation files (the "Software"), to deal
>  in the Software without restriction, including without limitation the rights
>  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
>  copies of the Software, and to permit persons to whom the Software is
>  furnished to do so, subject to the following conditions:
>
>  The above copyright notice and this permission notice shall be included in
>  all copies or substantial portions of the Software.
>
>  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
>  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
>  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
>  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
>  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
>  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
>  THE SOFTWARE.
