![FingClr Logo](https://github.com/ConnorSMaynes/FingClr/blob/master/MEDIA/IMAGES/LOGO.jpg)

# FingClr
Machine learning ( RNN (Recurrent Neural Network) and SVM (Support Vector Machine) ) recognition/classification of 7 hand gestures using 6 channels of BioRadio 150 &amp; BioCapture.

#### Note: This is for educational purposes, as part of the coursework for the Biorobotics & Cybernetics Course at RIT.

## Detailed Report on Implementation
- [FingClr Report](https://github.com/ConnorSMaynes/FingClr/blob/master/DOCUMENTATION/REPORT.docx)
- [FingClr Presentation](https://github.com/ConnorSMaynes/FingClr/blob/master/DOCUMENTATION/Bio%20Kennedy%20Maynes%20Presentation.pptx)

## Quick Start
- Download the repo
- Open MatLab and change path to directory of repo
- Open DEMO.m and edit `DataDir` and `ValidationDataDir` to match the locations of the data on your computer
- Run Options
  - `UseValidationData` : Set to 1 to train and test on the validation dataset. Set to 0 to use the collected EMG data.
  - `NeedDataForPlots` : Set to 1 if training the SVM. Optionally set to 1 for training the RNN, if you want to view plots of the data.
  - `DemoCNN` : Set to 1 to train a new RNN. Models with testing accuracies greater than 90% are automatically saved to the Models folder.
  - `DemoSVM` : Set to 1 to train a new SVM. Models with testing accuracies greater than 90% are automatically saved to the Models folder.
  - `RunCount` : How many times the model(s) should be trained before the overall confusion matrices are generated.
  - `TestRatio` : What ratio of the data to reserve for testing.
  - `ShowModelDemo` : Set to 1 to load an SVM trained model / RNN trained model. You will need to modify the paths in the DEMO.m file.
  - `BuildModels` : Set to 1 to build new models. Set to 0 to skip building of new models.

