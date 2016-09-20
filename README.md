# Analyze Histology

This repository contains a set of MATLAB tools for annotated and analyzing histology, especially designed for looking at implants such as electrodes. 

## Usage

Either add the directory to your MATLAB path, or navigate to the directory containing the code, and then run:

```
start_analyzer
```

This will launch a basic interface for opening new instances of the annotator. Click the "Load Image" button and select an image that you want to annotate. A window will come up with a toolbar and a copy of the images, where you can begin annotating.

The toolbar contains the following buttons:

* An open icon, to load existing annotations.
* A save icon, to save the current annotations.
* A line button, which allows you to specify the scale for the image.
* A layers button, which brings up the channels of the image (assumes blue is DAPI and red is NeuN).
* An ellipse button, which will calculate different statistics about the implant.
* A green circle, used to for annotating implants.
* An orange circle, used for annotating cells.

The interface is shown below:

![Interface](https://github.com/gardner-lab/implant-histology-analysis/blob/master/images/usage.png)

## Known issues

This code was tailor written for a specific use case, but hopefully can be applied to other use cases. Assumptions about the channels, the statistics to analyze and other details may not apply to other use cases and will require modification.

## Details

This code is licensed under the MIT license. It was created by [L. Nathan Perkins](https://github.com/nathanntg).
