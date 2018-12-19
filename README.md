F16 Video Dataset
=================

* Author    : Pablo Arias <pariasm@gmail.com>
* Copyright : (C) 2018 IPOL Image Processing On Line http://www.ipol.im/
* Licence   : GPL v3+, see LICENSE

OVERVIEW
--------

Code to generate a data set comprised of segments of 16 consecutive frames
extracted from videos. The videos are downloaded from the web using the 
command line program [youtube-dl](https://rg3.github.io/youtube-dl/). The code
consists of some C simple image manipulation functions (stolen 
from [imscript](https://github.com/mnhrdt/imscript) by Enric Meinhardt-Llopis)
and a bash script `url-to-bursts.sh`. It has been tested in Ubuntu 16.04.

The script takes as inputs the url of a video and a destination folder and
performs the following steps:

1. Creates the destination folder
2. Download the full video using [youtube-dl](https://rg3.github.io/youtube-dl/)
3. Extracts from the video bursts of 16 frames using
	[ffmpeg](https://ffmpeg.org/). The burst are evenly spaced throughout the
	video. The minimal time between consecutive bursts is 10s. The maximum
	number of bursts is 20.  These parameters can be configured by editing the
	script.
3. Downscales the extracted frames to 540 rows. To avoid aliasing a Gaussian filter
   is applied before downscaling. The scale of the filter is
	```sigma = sigma0*sqrt(factor^2 - 1)```
	to avoid introducing a bias in the dataset, we draw `sigma0` at random for each
	burst (within a certain range).
4. Removes the video file.

The bursts are left as sequences of png files in separate folders 01, 02, etc.

DEPENDENCIES
------------

To compile the image tools we need
- libpng
- libtiff
- libjpeg
- libfftw

We also need the following command line programs to be installed in the system:
- [youtube-dl](https://rg3.github.io/youtube-dl/)
- [ffmpeg](https://ffmpeg.org/)
- [jq](https://github.com/stedolan/jq) (a commandline JSON processor)


COMPILATION
-----------

The code is compilable on Unix/Linux (probably on Mac OS as well, but we didn't test). 
We provide a simple Makefile to compile the C code.
```
$ cd imscript-lite && make && cd ..
```

USAGE
-----

To download the bursts in a url:

```$ ./url-to-bursts.sh [url] [folder]```

To download all the bursts for the videos provided in the url folder:

```$ . download-all-bursts```

To generate the download-all-bursts file from a forder with many url files

```$ ./generate-command.sh```

URLS
----

We provide a set of urls from youtube videos that were used to train 
the video denoising network described in [this paper](https://arxiv.org/abs/1811.12758).
These urls were selected by Jessie Levillain and Raymond Zhang while they were 
interns at [CMLA](http://cmla.ens-paris-saclay.fr). The urls were collected by
searching in youtube using 64 queries. Only videos with Creative Commons license and
with at least HD resolution were downloaded. Videos were selected according to the
following criteria:
- avoid videos with a lot of camera shake
- avoid videos which are too blurry
- avoid videos that are compressed with low quality
- avoid videos with violent or sensitive content
- avoid slideshows videos or videos that have still images
- avoid computer graphics videos
- avoid videos with a lot of special effects
- avoid videos with a lot of banners

