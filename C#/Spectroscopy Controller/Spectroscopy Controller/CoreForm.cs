﻿using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;
using System.IO;
//using System.Math;



namespace Spectroscopy_Controller
{
    public partial class CoreForm : Form
    {
        // Store viewer as a private member - this means we can check if it has been initialised or not without causing a crash
        private Spectroscopy_Viewer.SpectroscopyViewerForm myViewer;

        // This has to be a member since we cannot pass parameters to FPGAReadMethod (due to threading)
        // Array of file names for data files
        string[] myFileName;


        TreeNode PreviewNode = new TreeNode();
        //TemplateSelector TemplateForm;

        private bool PauseExperiment = false;

        private bool bIsFreqGenEnabled = false;

        public bool updating = false;

        //Logic to select which source is used for 729 via RF switches
        private bool RFSwitch1State = false;
        private bool RFSwitch2State = false;
        
        //Trap and ion parameters
        private float dnought = 0.0189F;
        private float bField = 1.845F;
        private float ionmass = 40;
        private float ioncharge = 1;
        private float truecycFreq;
        private float pi = 3.1415927F;
        private float emratio = 0.9648533E8F;//(=1/1.036427E-8F);
 
        //Scan parameters for given run (taken from user selected values on form)
        private string specType, specDir;
        private int startFreq, carFreq, stepSize, sbToScan, sbWidth;
        private float trapV, axFreq, modcycFreq, magFreq, rfAmp;

        private int[] startFreqArray;

        public CoreForm()
        {
            InitializeComponent();

            truecycFreq = (emratio * ioncharge * bField / ionmass);
            //Console.WriteLine(truecycFreq/2/pi);
        }

        
        private void SetRFSpecButton_Click(object sender, EventArgs e)
        {
            int Frequency = (int)SpecRFFreq.Value;
            float Amplitude = (float)SpecRFAmp.Value;

            GPIB.InitDevice(19);
            GPIB.SetAmplitude(Amplitude);
            GPIB.SetFrequency(Frequency);
            GPIB.CloseDevice();
        }

        private void SetRFSB1Button_Click(object sender, EventArgs e)
        {
            int Frequency = (int)SB1RFFreq.Value;
            float Amplitude = (float)SB1RFAmp.Value;

            GPIB.InitDevice(20);
            GPIB.SetAmplitude(Amplitude);
            GPIB.SetFrequency(Frequency);
            GPIB.CloseDevice();
        }

        private void SetRFSB2Button_Click(object sender, EventArgs e)
        {
            int Frequency = (int)SB2RFFreq.Value;
            float Amplitude = (float)SB2RFAmp.Value;

            GPIB.InitDevice(21);
            GPIB.SetAmplitude(Amplitude);
            GPIB.SetFrequency(Frequency);
            GPIB.CloseDevice();
        }

        private void SetRFSB3Button_Click(object sender, EventArgs e)
        {
            int Frequency = (int)SB3RFFreq.Value;
            float Amplitude = (float)SB3RFAmp.Value;

            GPIB.InitDevice(22);
            GPIB.SetAmplitude(Amplitude);
            GPIB.SetFrequency(Frequency);
            GPIB.CloseDevice();
        }

        private void LaserBoxChanged(object sender, EventArgs e)
        {

            if (!FPGA.bUSBPortIsOpen)
            {
                MessageBox.Show("USB Port not open");
                return;
            }
           
            string RFtype = "Laser";

           if (sender is System.Windows.Forms.CheckBox)
            {
                RFtype = "Laser";
            }
            else if (sender is System.Windows.Forms.RadioButton)
            {
            RFtype = ((RadioButton)sender).Tag.ToString();
            }

            switch(RFtype)
            {
               case "Laser":
                    SetOutputs();
                    break; 
               case "Spec":
                    RFSwitch1State = false;
                    RFSwitch2State = false;
                    SB1RFSourceButton.Checked = false;
                    SB2RFSourceButton.Checked = false;
                    SB3RFSourceButton.Checked = false;                              
                    SetOutputs();
                    break; 
               case "SB1":
                    RFSwitch1State = true;
                    RFSwitch2State = false;
                    SpecRFSourceButton.Checked = false;
                    SB2RFSourceButton.Checked = false;
                    SB3RFSourceButton.Checked = false;
                    SetOutputs();
                    break; 
               case "SB2":
                    RFSwitch1State = false;
                    RFSwitch2State = true;
                    SpecRFSourceButton.Checked = false;
                    SB1RFSourceButton.Checked = false;
                    SB3RFSourceButton.Checked = false;
                    SetOutputs();
                    break; 
               case "SB3":
                    RFSwitch1State = true;
                    RFSwitch2State = true;
                    SpecRFSourceButton.Checked = false;
                    SB1RFSourceButton.Checked = false;
                    SB2RFSourceButton.Checked = false;
                    SetOutputs();
                    break; 
            }
        }

        public void SetOutputs()
        {
            FPGA.SetLasers(LiveLaserBox397B1.Checked,
                           LiveLaserBox397B2.Checked,
                           LiveLaserBox729.Checked,
                           LiveLaserBox854.Checked,
                           RFSwitch1State,
                           RFSwitch2State,
                           LiveLaserBox854POWER.Checked,
                           LiveLaserBox854FREQ.Checked,
                           LiveLaserBoxAux1.Checked,
                           LiveLaserBoxAux2.Checked);
        }

        /*private void OnFormClosing(object sender, EventArgs e) //clean up any threads left running
        {
            if ((BinarySendThread != null) && (BinarySendThread.IsAlive))
            {
                BinarySendThread.Abort();
                BinarySendThread.Join();
            }

            if ((FPGAReadThread != null) && (FPGAReadThread.IsAlive))
            {
                FPGAReadThread.Abort();
                FPGAReadThread.Join();
            }
        } */

        #region Methods defined in FPGAControls.cs

        private void OpenUSBButton_Click(object sender, EventArgs e)
        {
            OpenUSBPort();       
        }

        /*private void StartButton_Click(object sender, EventArgs e)
        {
            if (FPGA.bUSBPortIsOpen == false)
            {
                WriteMessage("Can't Send Start Signal to FPGA: USB port is not open", true);
                return;
            }
            bShouldQuitThread = false;

            int WindowSize = 0;
            int WindowGap = 0;

            if (FreqSelectForm.GetFreqGenEnable())
            {
                bIsFreqGenEnabled = true;
                float Amplitude = FreqSelectForm.GetAmplitude();
                GPIB.InitDevice(Amplitude);
                int Frequency = FreqSelectForm.GetInitialFrequency();
                GPIB.SetFrequency(Frequency);
                if (FreqSelectForm.GetWindowingEnable())
                {
                    bIsWindowingEnabled = true;
                    WindowSize = FreqSelectForm.GetWindowSize();
                    WindowGap = FreqSelectForm.GetSidebandSpacing() - FreqSelectForm.GetWindowSize();                   
                }
                else bIsWindowingEnabled = false;
            }
            else
            {
                bIsFreqGenEnabled = false;
            }

            float FrequencyAmp = FreqSelectForm.GetAmplitude();
            int Frequencystep = FreqSelectForm.GetFreqStep();
            int Frequencystart = FreqSelectForm.GetInitialFrequency();

            ResultsForm.StartConditions(Frequencystart, Frequencystep, FrequencyAmp, bIsWindowingEnabled, WindowSize, WindowGap);

            SendSetupFinish();         
            StartReadingData();
            
        }*/

        #endregion

        /*#region Methods defined in DebugTools.cs

        private void SendDataButton_Click(object sender, EventArgs e)
        {
            SendData();   //defined in DebugTools.cs  
        }

        private void ReadDataButton_Click(object sender, EventArgs e)
        {
            ReadData();  //defined in DebugTools.cs
        }

        #endregion*/

        #region Methods defined in XMLFIleIO.cs


        private void SaveXMLButton_Click(object sender, EventArgs e)
        {
            saveXMLFileDialog.ShowDialog();
        }

        private void saveXMLFileDialog_FileOk(object sender, CancelEventArgs e)
        {
            SaveXMLFile();
        }

        private void OpenXMLButton_Click(object sender, EventArgs e)
        {
            openXMLFileDialog.ShowDialog();
        }

        private void openXMLFileDialog_FileOk(object sender, CancelEventArgs e)
        {
            OpenXMLFile();
        }

        #endregion*/

        #region Methods defined in PulseTree.cs

        private void AddRootButton_Click(object sender, EventArgs e)
        {
            AddNewState(true);
        }

        private void AddChildButton_Click(object sender, EventArgs e)
        {
            AddNewState(false);
        }

        private void DeleteButton_Click(object sender, EventArgs e)
        {
            RemoveState();
        }        

        private void MoveUpButton_Click(object sender, EventArgs e)
        {
            MoveState(true);
        }

        private void MoveDownButton_Click(object sender, EventArgs e)
        {
            MoveState(false);
        }

        private void PulseTree_AfterSelect(object sender, TreeViewEventArgs e)
        {
            PulseTreeSelect();            
        }

        private void SaveStateButton_Click(object sender, EventArgs e)
        {
            SaveStateFromForm();
        }

        private void AddRootButton_MouseEnter(object sender, EventArgs e)
        {
            ManagePreviewNode(true, true);
        }

        private void AddRootButton_MouseLeave(object sender, EventArgs e)
        {
            ManagePreviewNode(true, false);
        }

        private void AddChildButton_MouseEnter(object sender, EventArgs e)
        {
            ManagePreviewNode(false, true);
        }

        private void AddChildButton_MouseLeave(object sender, EventArgs e)
        {
            ManagePreviewNode(false, false);
        }

        private int tickRounder()
        {
            //Find nearest number of integer ticks (640ns per tick) to desired pulse length
            int roundedTicks = (int)(TicksBox.Value * 1000 / 640);

            //Calculate rounded pulse length and display on form
            float roundedLength = (float)(roundedTicks * 0.64);
            string roundedLengthString = roundedLength.ToString("0.##");
            TimeLabel.Text = "Length = " + roundedLengthString + "us";

            return roundedTicks;
        }

        private void TicksBox_ValueChanged(object sender, EventArgs e)
        {
            tickRounder();
        }

        #endregion
              
        /*#region Methods defined in HexFileIO.cs

        private void compileToBinaryToolStripMenuItem_Click(object sender, EventArgs e)
        {
            saveHexFileDialog.ShowDialog();
        }

        private void saveHexFileDialog_FileOk(object sender, CancelEventArgs e)
        {
            SaveHexFile();
        }

        private void sendBinaryFileOnlyToolStripMenuItem_Click(object sender, EventArgs e)
        {
            if (FPGA.bUSBPortIsOpen == false)
            {
                WriteMessage("Can't Send Data to FPGA: USB port is not open", true);
                return;
            }

            openHexFileDialog.ShowDialog();
        }

        private void openHexFileDialog_FileOk(object sender, CancelEventArgs e)
        {
            SendBinaryFile();
        }

        private void sendBinaryFileStartSignalToolStripMenuItem_Click(object sender, EventArgs e)
        {
            sendBinaryFileOnlyToolStripMenuItem_Click(null, null);
            sendStartSignalToolStripMenuItem_Click(null, null);
        }

        #endregion*/        

        /*private void ChooseFileButton_Click(object sender, EventArgs e)
        {
            saveResultsFileDialog.ShowDialog();
        }

        private void saveResultsFileDialog_FileOk(object sender, CancelEventArgs e)
        {
            FilenameTextbox.Text = saveResultsFileDialog.FileName;
        }

        private void CreateFromTemplateButton_Click(object sender, EventArgs e)
        {            
            TemplateForm.ShowDialog();            
        }*/

        /*private void StopButton_Click(object sender, EventArgs e)
        {
            bShouldQuitThread = true;
        }*/

        /*private void frequencyGeneratorToolStripMenuItem_Click(object sender, EventArgs e)
        {
            FreqSelectForm.ShowDialog();            
        }*/

        private void ResetButton_Click(object sender, EventArgs e)
        {
            if (FPGA.bUSBPortIsOpen == false)
            {
                WriteMessage("Can't Send Reset Signal to FPGA: USB port is not open", true);
                return;
            }
            if (FPGAReadThread != null && FPGAReadThread.IsAlive)
            {
                bResetFPGA = true;
            }
            else
            {
                FPGA.SendResetSignal();
            }
            
        }

        // Method to respond to user clicking start button
        private void StartButton_Click(object sender, EventArgs e)
        {
            // If we are restarting the experiment after it being paused, just reset the PauseExperiment flag
            if (PauseExperiment == true)
            {
                PauseExperiment = false;        // Set flag
                PauseButton.Enabled = true;     // Re-enable pause button
            }
            else
            {   // Otherwise, start experiment

                // Want to:
                //- open dialog for user to specify file name (save file??) & put in metadata - no. of repeats and no. of spectra
                //- open an instance of spectroscopy viewer (if not already open...!) and specify live mode
                //- Pass metadata to viewer
                //- write metadata to file
                //- do all the things that the previous program did to start running the experiment

                if (FPGA.bUSBPortIsOpen == false)
                {
                    WriteMessage("Can't Send Start Signal to FPGA: USB port is not open", true);
                    return;
                }
                else
                {
                    //Grab all scan and trap parameters from form:
                    specType = specTypeBox.SelectedValue.ToString();
                    specDir = specDirBox.SelectedValue.ToString();
                    trapV = (float)(1000 * trapVBox.Value);   //Trap voltage stored in millivolts
                    axFreq = (float)(1000 * axFreqBox.Value);
                    modcycFreq = (float)(1000 * modcycFreqBox.Value);
                    magFreq = (float)(1000 * magFreqBox.Value);
                    startFreq = (int)(10000000 * startFreqBox.Value);
                    carFreq = (int)(10000000 * carFreqBox.Value);
                    stepSize = (int)(1000 * stepSizeBox.Value);
                    sbToScan = (int)sbToScanBox.Value;
                    sbWidth = (int)(1000 * sbWidthBox.Value);
                    rfAmp = (float)rfAmpBox.Value;
                    
                    // Metadata ordering in array:
                    // 0: Date
                    // 1: Spectrum type
                    // 2: 729 direction
                    // 3: Trap voltage
                    // 4: Axial freq
                    // 5: Modified cyc freq
                    // 6: Magnetron freq
                    // 7: AOM start freq (MHz)
                    // 8: Carrier freq (MHz)
                    // 9: Step size (kHz)
                    // 10: Sidebands/side
                    // 11: Sideband width (steps)
                    // 12: 729 RF amplitude
                    // 13: Number of repeats
                    // 14: Number interleaved
                    // 15: Which sideband
                    // 16 + i: spectrum i name


                    

                    // Create new dialog to get data from user before starting the experiment
                    StartExperimentDialog myExperimentDialog = new StartExperimentDialog();
                    myExperimentDialog.ShowDialog();
                    if (myExperimentDialog.DialogResult != DialogResult.Cancel)
                    {
                        // Create & fill in metadata
                        string[] metadata = new string[23];
                        metadata[0] = DateTime.UtcNow.ToString("d/m/yyyy HH:MM:SS");
                        // This is all from the CoreForm
                        metadata[1] = specType;
                        metadata[2] = specDir;
                        metadata[3] = this.trapVBox.Value.ToString();
                        metadata[4] = this.axFreqBox.Value.ToString();
                        metadata[5] = this.modcycFreqBox.Value.ToString();
                        metadata[6] = this.magFreqBox.Value.ToString();
                        metadata[7] = this.startFreqBox.Value.ToString();
                        metadata[8] = this.carFreqBox.Value.ToString();
                        metadata[9] = this.stepSizeBox.Value.ToString();
                        metadata[10] = this.sbToScanBox.Value.ToString();
                        metadata[11] = this.sbWidthBox.Value.ToString();
                        metadata[12] = this.rfAmpBox.Value.ToString();
                        // Fill in remaining metadata from form
                        metadata[13] = myExperimentDialog.NumberOfRepeats.Value.ToString();
                        metadata[14] = myExperimentDialog.NumberOfSpectra.Value.ToString();

                        int numberOfSpectra = (int)myExperimentDialog.NumberOfSpectra.Value;

                        for (int i = 0; i < numberOfSpectra; i++)
                        {
                            metadata[i + 15] = myExperimentDialog.SpectrumNames[i].Text;
                        }

                        metadata[15 + numberOfSpectra] = myExperimentDialog.NotesBox.Text;


                        // Retrieve the folder path selected by the user
                        string FolderPath = myExperimentDialog.getFilePath();
                        // Make sure the 
                        if (FolderPath != null)
                        {
                            TextWriter[] myFile;        // Declare array of files

                            // If "Continuous" experiment type has been selected
                            if (specType == "Continuous")
                            {
                                //Turn on frequency generator
                                bIsFreqGenEnabled = true;

                                //Start frequency is the value taken directly from the form, no windowing
                                startFreqArray = new int[1];
                                startFreqArray[0] = startFreq;

                                // Create a single file and put all readings in there
                                myFileName = new string[1];
                                myFile = new TextWriter[1];

                                // Create the file with appropriate name & write metadata to it
                                writeMetadataToFile(ref myExperimentDialog, ref FolderPath, ref myFile, 1);

                                // If myViewer is not open
                                if (myViewer == null)
                                {
                                    // Create new instance of viewer
                                    myViewer = new Spectroscopy_Viewer.SpectroscopyViewerForm(ref metadata);
                                }
                            }
                            else if (specType == "Windowed")
                            {
                                //Turn on frequency generator
                                bIsFreqGenEnabled = true;

                                //Calculate frequency offset of sideband start frequencies from sideband centres
                                int offsetFreq = (int)stepSize*sbWidth/2;
                                //Determine window spacing from trap frequencys and the type of spectrum selected

                                int windowSpace = 0;
                                if (specDir == "Axial") windowSpace = (int)axFreq;
                                else if (specDir == "Radial") windowSpace = (int)modcycFreq;

                                //Array of start frequencies for each sideband (from furthest red to furthest blue)            
                                startFreqArray = new int[sbToScan * 2 + 1];
                                for (int sb = 0; sb < (sbToScan * 2 + 1); sb++)
                                {
                                    startFreqArray[sb] = carFreq - offsetFreq - (windowSpace * (sbToScan - sb));
                                }

                                // We want a file for each sideband with appropriate naming
                                // Calculate how many files we will need - one for each R/B sideband plus one for carrier
                                int numberOfFiles = (int)(sbToScan * 2 + 1);
                                // Create array of filenames & array of files
                                myFileName = new string[numberOfFiles];
                                myFile = new TextWriter[numberOfFiles];
                                // Generate filenames and actually create files
                                writeMetadataToFile(ref myExperimentDialog, ref FolderPath, ref myFile, numberOfFiles);
                            }
                            else if (specType == "Fixed")
                            {
                                bIsFreqGenEnabled = false;
                            }
                        }
                        else
                        {
                            MessageBox.Show("Error selecting folder. Please try again.");
                        }



                        // Start the experiment running
                        // The following code has been copied from MainForm.cs (method sendStartSignalToolStripMenuItem_Click)
                        /*
                        bShouldQuitThread = false;

                        int WindowSize = 0;
                        int WindowGap = 0;

                        if (FreqSelectForm.GetFreqGenEnable())
                        {
                            bIsFreqGenEnabled = true;
                            float Amplitude = FreqSelectForm.GetAmplitude();
                            GPIB.InitDevice(Amplitude);
                            int Frequency = FreqSelectForm.GetInitialFrequency();
                            GPIB.SetFrequency(Frequency);
                            if (FreqSelectForm.GetWindowingEnable())
                            {
                                bIsWindowingEnabled = true;
                                WindowSize = FreqSelectForm.GetWindowSize();
                                WindowGap = FreqSelectForm.GetSidebandSpacing() - FreqSelectForm.GetWindowSize();
                            }
                            else bIsWindowingEnabled = false;
                        }
                        else
                        {
                            bIsFreqGenEnabled = false;
                        }

                        float FrequencyAmp = FreqSelectForm.GetAmplitude();
                        int Frequencystep = FreqSelectForm.GetFreqStep();
                        int Frequencystart = FreqSelectForm.GetInitialFrequency();

                    
                        SendSetupFinish();
                        StartReadingData();
                        */
                    }

                }

            }

        }

        // Method to respond to using clicking Pause button
        private void PauseButton_Click(object sender, EventArgs e)
        {
            // Only let it pause if the experiment is running (need to check this)
            if (FPGAReadThread.IsAlive)
            {
                // Flag to pause. This is detected within the FPGARead method (in FPGAControls)
                PauseExperiment = true;
                PauseButton.Enabled = false;
            }
        }

        // Method to write the metadata to files
        // Gets filenames from private member myFileName
        private void writeMetadataToFile(   ref StartExperimentDialog myExperimentDialog, ref string FolderPath,
                                            ref TextWriter[] myFile, int numberOfFiles  )
        {
            // These variables are needed for windowed files only
            // But need to create them anyway else C# will complain...
            //*****************//
            // Store the number sideband we are on
            int sbCurrent = sbToScan;
            // Store whether we are on a red or blue sideband
            char sbRedOrBlue = 'R';
            //*****************//

            // Go through each file
            for (int i = 0; i < numberOfFiles; i++)
            {
                // Generating the current filename:
                //*******************************//
                // This line happens for both continuous & windowed files
                myFileName[i] = FolderPath + @"\" + myExperimentDialog.ExperimentName.Text + "_readings";

                // These bits only need adding to windowed files
                if (specType == "Windowed")
                {
                    myFileName[i] += "_";

                    // Add preceding 0s to keep format of sideband number as XXX
                    if (sbCurrent < 10) myFileName[i] += "00";
                    else if (sbCurrent < 100) myFileName[i] += "0";

                    // Add current sideband number to filename
                    myFileName[i] += sbCurrent;
                    // If not on carrier, add R or B
                    if (sbCurrent != 0) myFileName[i] += sbRedOrBlue;
                }
                myFileName[i] += ".txt";
                //*******************************//

                // Now we get to actually create the file!
                myFile[i] = new StreamWriter(myFileName[i]);

                //*********************************//
                // Write the metadata to the file
                //
                myFile[i].WriteLine("Spectroscopy data file");
                myFile[i].WriteLine(DateTime.Now.ToString("d/m/yyyy HH:MM:SS"));
                // Spectrum type
                myFile[i].WriteLine("Spectrum Type:");
                myFile[i].WriteLine(specType);
                // 729 direction
                myFile[i].WriteLine("729 Direction:");
                myFile[i].WriteLine(specDir);
                // Trap voltage
                myFile[i].WriteLine("Trap Voltage (V):");
                myFile[i].WriteLine(this.trapVBox.Value);
                // Axial frequency
                myFile[i].WriteLine("Axial Frequency (kHz):");
                myFile[i].WriteLine(this.axFreqBox.Value);
                // Modified cyc freq
                myFile[i].WriteLine("Modified Cyclotron Frequency (kHz):");
                myFile[i].WriteLine(this.modcycFreqBox.Value);
                // Magnetron freq
                myFile[i].WriteLine("Magnetron Frequency (kHz):");
                myFile[i].WriteLine(this.magFreqBox.Value);
                // AOM start freq
                myFile[i].WriteLine("AOM Start Frequency (MHz):");
                myFile[i].WriteLine(startFreqArray[i]);
                // Carrier frequency
                myFile[i].WriteLine("Carrier Frequency (MHz):");
                myFile[i].WriteLine(this.carFreqBox.Value);
                // Step size
                myFile[i].WriteLine("Step Size (kHz):");
                myFile[i].WriteLine(this.stepSizeBox.Value);
                // Sidebands/side
                myFile[i].WriteLine("Sidebands to scan / side:");
                myFile[i].WriteLine(sbToScan);
                // Sideband width
                myFile[i].WriteLine("Sideband Width (steps):");
                myFile[i].WriteLine(sbWidth);
                // 729 RF amplitude
                myFile[i].WriteLine("729 RF Amplitude (dBm):");
                myFile[i].WriteLine(rfAmp);
                // Number of repeats
                myFile[i].WriteLine("Number of repeats per frequency:");
                myFile[i].WriteLine(myExperimentDialog.NumberOfRepeats.Value);
                // Number interleaved
                myFile[i].WriteLine("File contains interleaved spectra:");
                myFile[i].WriteLine(myExperimentDialog.NumberOfSpectra.Value);
                // Sideband number
                myFile[i].WriteLine("This is sideband:");
                myFile[i].WriteLine(sbCurrent + sbRedOrBlue);
                // Name for each spectrum
                for (int j = 0; j < myExperimentDialog.NumberOfSpectra.Value; j++)
                {
                    myFile[i].WriteLine("Spectrum " + j + " name:");
                    myFile[i].WriteLine(myExperimentDialog.SpectrumNames[j].Text);
                }
                // Notes section
                myFile[i].WriteLine("Notes:");
                myFile[i].WriteLine(myExperimentDialog.NotesBox.Text);
                // Title for data
                myFile[i].WriteLine("Data:");

                // Flush & close the file
                myFile[i].Flush();
                myFile[i].Close();
                //*********************************//

                // For the next filename:
                // Only needs to happen for windowed files
                //*********************//
                if (specType == "Windowed")
                {

                    // If we are still on the red side, just decrease the sideband number
                    if (i < sbToScan) sbCurrent--;
                    else if (i == sbToScan)
                    // If we have reached the carrier
                    {
                        // Change R to B
                        sbRedOrBlue = 'B';
                        // Increase sideband number
                        sbCurrent++;
                    }
                    // If we are on the blue side, just increase the sideband number
                    else sbCurrent++;
                }

            } //End of loop which goes through each file

        }



        private void trapVBox_ValueChanged(object sender, EventArgs e)
        {
            if (updating == false)
            {
                trapV = (float)(1000 * trapVBox.Value);
                UpdateTrapFreqs();
            }
        }

        private void axFreqBox_ValueChanged(object sender, EventArgs e)
        {
            if (updating == false)
            {
                axFreq = 2 * pi * 1000 * (float)axFreqBox.Value;
                trapV = (float)(1000 * Math.Pow(axFreq, 2) * Math.Pow(dnought, 2) * ionmass / ioncharge / emratio / 4);
                Console.WriteLine(axFreq);
                Console.WriteLine(trapV);
                UpdateTrapFreqs();
            }
        }

        private void modcycFreqBox_ValueChanged(object sender, EventArgs e)
        {
            if (updating == false)
            {
                modcycFreq = 2 * pi * 1000 * (float)modcycFreqBox.Value;
                trapV = (float)((1000 * Math.Pow(dnought, 2) * ionmass / ioncharge / emratio / 2) * (truecycFreq * modcycFreq - Math.Pow(modcycFreq, 2)));
                UpdateTrapFreqs();
            }
        }

        private void magFreqBox_ValueChanged(object sender, EventArgs e)
        {
            if (updating == false)
            {
               magFreq = (float)(2 * pi * (float)(1000 * magFreqBox.Value));
               trapV = (float)((1000 * Math.Pow(dnought, 2) * ionmass / ioncharge / emratio / 2) * (truecycFreq * magFreq - Math.Pow(magFreq, 2)));
               UpdateTrapFreqs();
            }
        }

        private void UpdateTrapFreqs()
        {
            updating = true;
            axFreq = (float)(Math.Sqrt(4 * emratio * ioncharge * trapV / 1000 / ionmass / Math.Pow(dnought,2) ) );
            magFreq = (float)((truecycFreq - Math.Sqrt(Math.Pow(truecycFreq,2) - 2 * Math.Pow(axFreq,2) ) ) / 2);
            modcycFreq = (float)((truecycFreq + Math.Sqrt(Math.Pow(truecycFreq, 2) - 2 * Math.Pow(axFreq,2) ) ) / 2);
            axFreqBox.Value = (decimal)(axFreq/1000/2/pi);
            magFreqBox.Value = (decimal)(magFreq/1000/2/pi);
            modcycFreqBox.Value = (decimal)(modcycFreq/1000/2/pi);
            trapVBox.Value = ((decimal)trapV/1000);
            updating = false;
        }


        /*private void fPGAToolStripMenuItem_Click(object sender, EventArgs e)      //Greys out end read thread item when not running
        {
            if (FPGAReadThread != null && FPGAReadThread.IsAlive)
            {
                endReadThreadToolStripMenuItem.Enabled = true;
            }
            else
            {
                endReadThreadToolStripMenuItem.Enabled = false;
            }
        }*/
    }
}
