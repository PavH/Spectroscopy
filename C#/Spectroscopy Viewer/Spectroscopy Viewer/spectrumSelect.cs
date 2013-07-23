﻿using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;

namespace Spectroscopy_Viewer
{
    public partial class spectrumSelect : Form
    {
        // List to display 
        private BindingList<string>[] myListOfSpectra;
        // Store the number of existing spectra
        private int existingSpectra = new int();
        // Store the number of interleaved spectra in file
        private int numberInterleaved = new int();
        // Combo boxes for user input
        private ComboBox[] myComboBox;


        // To store names of the new spectra to be created
        private List<string> newSpectra = new List<string>();

        // Public variables to be accessed by main form
        public int[] selectedSpectrum;        // Which option selected for each data set
        public List<string> spectrumNames = new List<string>();     // List of names

        // Constructor given a list of existing spectra
        public spectrumSelect(List<spectrum> mySpectrum, int numberInterleavedPassed, string myFileName)
        {
            InitializeComponent();


            int numberInterleaved = numberInterleavedPassed;    // Store number of spectra in the file
            existingSpectra = mySpectrum.Count();               // Store number of existing spectra
            selectedSpectrum = new int[numberInterleaved];      // Initialise array

            // Create lists for drop-down boxes
            myListOfSpectra = new BindingList<string>[numberInterleaved];
            myListOfSpectra[0] = new BindingList<string>();

            // Create new item in list for each existing spectrum
            for (int i = 0; i < existingSpectra; i++)
            {
                spectrumNames[i] = mySpectrum[i].getName();                     // Retrieve name of spectrum
                myListOfSpectra[0].Add("Spectrum " + (i+1) + " (" + spectrumNames[i] + ")");    // Concatenate string with name & number
            }
            myListOfSpectra[0].Add("");    // Add a blank option

            // Duplicate list
            for (int i = 1; i < numberInterleaved; i++)
            {
                myListOfSpectra[i] = myListOfSpectra[0];
            }

            // Set defaults for text box
            newSpectrumNameBox.MaxLength = 100;          // Set a sensible maximum length for spectrum name
            
            // Set text telling the user how many spectra have been detected
            detectedSpectraText.Text = "Valid file " + myFileName + " opened \nFile contains "
                                        + numberInterleaved + " interleaved spectra"
                                        + "\nPlease choose destinations:";


            //********************************//
            // Create combo boxes & labels dynamically, depending on number of interleaved spectra
            //********************************//
            myComboBox = new ComboBox[numberInterleaved];               // Create combo boxes
            Label[] myComboBoxLabel = new Label[numberInterleaved];     // Create labels

            // Create combo boxes and set data source
            for (int i = 0; i < numberInterleaved; i++)
            {
                myComboBoxLabel[i] = new Label();
                myComboBoxLabel[i].Text = "Spectrum " + (i+1) + ":";
                myComboBoxLabel[i].Location = new Point(200, 10 + i * 30);
                myComboBoxLabel[i].Size = new System.Drawing.Size(70, 13);
                this.Controls.Add(myComboBoxLabel[i]);

                myComboBox[i] = new ComboBox();
                myComboBox[i].DataSource = myListOfSpectra;
                myComboBox[i].Location = new Point(280, 10 + i * 30);
                myComboBox[i].Size = new System.Drawing.Size(220, 21);
                this.Controls.Add(myComboBox[i]);
                this.myComboBox[i].SelectedIndexChanged +=
                    new System.EventHandler(this.myComboBox_SelectedIndexChanged);
            }
            //********************************//

            // Set text on button to singular/plural depending on number of spectra (just being fancy really)
            if (numberInterleaved == 1)
            {
                buttonOK.Text = "Load spectrum";
            }
            else buttonOK.Text = "Load spectra";

 
        }


        private void addNewSpectrumButton_Click(object sender, EventArgs e)
        {
            // Add name to temporary list of new spectra to be created
            newSpectra.Add(newSpectrumNameBox.Text);

            // Add spectra to all lists
            for (int i = 0; i < numberInterleaved; i++)
            {
                myListOfSpectra[i].Add("(New) " + newSpectrumNameBox.Text);
            }
            // NB drop-down lists automatically update

        }

        private void buttonOK_Click(object sender, EventArgs e)
        {

            // For each of the interleaved spectra
            for (int i = 0; i < numberInterleaved; i++)
            {
                if (selectedSpectrum[i] >= existingSpectra)
                {
                    // Re-order so that the next spectrum to be dealt with is the next in the array
                    // This ensures correct metadata when items are added to list using List.Add
                    spectrumNames.Add(newSpectra[selectedSpectrum[i] - existingSpectra]);
                }
            }

            this.Close();       // Close form
        }

        // Handles change of selected index for all combo boxes
        private void myComboBox_SelectedIndexChanged(object sender, EventArgs e)
        {
            // For each drop-down box
            for (int i = 0; i < numberInterleaved; i++)
            {
                // Assign which spectrum each data set should belong to - from user input on form
                selectedSpectrum[i] = myComboBox[i].SelectedIndex;
            }

            // For each drop-down box
            for (int i = 0; i < numberInterleaved; i++)
            {
                // Check other drop-down boxes
                for (int j = 0; j < numberInterleaved; i++)
                {
                    // Ignore selection made by this combo box
                    if (j != i)
                    {
                        // Disable item in list that corresponds to selectedSpectrum[j]
                    }
                }
            }

        }


    }
}
