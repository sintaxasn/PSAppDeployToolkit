using System;
using System.Windows;
using System.Windows.Controls;
using PSADT.UserInterface.DialogOptions;
using PSADT.UserInterface.DialogResults;

namespace PSADT.UserInterface.Interfaces.Fluent
{
    /// <summary>
    /// A fluent implementation of PSAppDeployToolkit's Custom dialog.
    /// </summary>
    internal class CustomDialog : FluentDialog, IModalDialog
    {
        /// <summary>
        /// Initializes a new instance of the CustomDialog class using the specified dialog options.
        /// </summary>
        /// <remarks>This constructor sets the default dialog result to "Timeout".</remarks>
        /// <param name="options">The options that configure the behavior and appearance of the dialog.</param>
        internal CustomDialog(CustomDialogOptions options) : this(options, CustomDialogResult.DefaultResult)
        {
        }

        /// <summary>
        /// Instantiates a new Custom dialog.
        /// </summary>
        /// <param name="options">Mandatory options needed to construct the window.</param>
        /// <param name="dialogResult">An object to store the dialog result in.</param>
        private protected CustomDialog(CustomDialogOptions options, CustomDialogResult dialogResult) : base(options, dialogResult)
        {
            // Set up UI
            FormatMessageWithHyperlinks(MessageTextBlock, options.MessageText);
            ButtonPanel.Visibility = Visibility.Visible;

            // Configure buttons based on provided texts
            if (options.ButtonLeftText is not null)
            {
                SetButtonContentWithAccelerator(ButtonLeft, options.ButtonLeftText);
                ButtonLeft.Visibility = Visibility.Visible;
                if (options.DefaultButton is DialogDefaultButton.Left)
                {
                    SetDefaultButton(ButtonLeft);
                    SetAccentButton(ButtonLeft);
                }
            }
            if (options.ButtonMiddleText is not null)
            {
                SetButtonContentWithAccelerator(ButtonMiddle, options.ButtonMiddleText);
                ButtonMiddle.Visibility = Visibility.Visible;
                if (options.DefaultButton is DialogDefaultButton.Middle)
                {
                    SetDefaultButton(ButtonMiddle);
                    SetAccentButton(ButtonMiddle);
                }
            }
            if (options.ButtonRightText is not null)
            {
                SetButtonContentWithAccelerator(ButtonRight, options.ButtonRightText);
                ButtonRight.Visibility = Visibility.Visible;
                if (options.DefaultButton is DialogDefaultButton.Right)
                {
                    SetDefaultButton(ButtonRight);
                    SetAccentButton(ButtonRight);
                }
            }

            // Wire keyboard activation conventions when more than one button is shown: Enter activates the
            // first visible (primary) button, Esc activates the last visible (typically cancel) button.
            // The single-button case is already handled by the base UpdateButtonLayout.
            System.Collections.Generic.List<Fluence.Wpf.Controls.Button> visibleButtons = [];
            if (ButtonLeft.Visibility is Visibility.Visible)
            {
                visibleButtons.Add(ButtonLeft);
            }
            if (ButtonMiddle.Visibility is Visibility.Visible)
            {
                visibleButtons.Add(ButtonMiddle);
            }
            if (ButtonRight.Visibility is Visibility.Visible)
            {
                visibleButtons.Add(ButtonRight);
            }
            if (visibleButtons.Count > 1)
            {
                SetDefaultButton(visibleButtons[0]);
                SetCancelButton(visibleButtons[^1]);
            }
        }

        /// <inheritdoc />
        private protected override FrameworkElement? GetInitialFocusElement()
        {
            return ButtonLeft.Visibility is Visibility.Visible ? ButtonLeft
                : ButtonMiddle.Visibility is Visibility.Visible ? ButtonMiddle
                : ButtonRight.Visibility is Visibility.Visible ? ButtonRight
                : null;
        }

        /// <summary>
        /// Handles the click event for the left button, updating the dialog result if it is still set to the default
        /// value.
        /// </summary>
        /// <remarks>The default-value guard lets a derived class set DialogResult first without this override
        /// overwriting it.</remarks>
        /// <param name="sender">The source of the event, typically the button that was clicked.</param>
        /// <param name="e">The event data associated with the click event.</param>
        private protected override void ButtonLeft_Click(object? sender, RoutedEventArgs e)
        {
            // Only set DialogResult if it hasn't been set by a derived class (still has default "Timeout" value).
            if (CustomDialogResult.DefaultResult.Equals(DialogResult))
            {
                DialogResult = new CustomDialogResult(((AccessText)ButtonLeft.Content).Text.Replace("_", newValue: null, StringComparison.Ordinal));
            }
            base.ButtonLeft_Click(sender, e);
        }

        /// <summary>
        /// Handles the click event for the middle button in the dialog, updating the dialog result if it has not
        /// already been set by a derived class.
        /// </summary>
        /// <remarks>The default-value guard lets a derived class set DialogResult first without this override
        /// overwriting it.</remarks>
        /// <param name="sender">The source of the event, typically the middle button that was clicked.</param>
        /// <param name="e">The event data associated with the button click.</param>
        private protected override void ButtonMiddle_Click(object? sender, RoutedEventArgs e)
        {
            // Only set DialogResult if it hasn't been set by a derived class (still has default "Timeout" value).
            if (CustomDialogResult.DefaultResult.Equals(DialogResult))
            {
                DialogResult = new CustomDialogResult(((AccessText)ButtonMiddle.Content).Text.Replace("_", newValue: null, StringComparison.Ordinal));
            }
            base.ButtonMiddle_Click(sender, e);
        }

        /// <summary>
        /// Handles the click event for the right button in the dialog, updating the dialog result if it has not already
        /// been set by a derived class.
        /// </summary>
        /// <remarks>The default-value guard lets a derived class set DialogResult first without this override
        /// overwriting it.</remarks>
        /// <param name="sender">The source of the event, typically the right button that was clicked.</param>
        /// <param name="e">The event data associated with the button click.</param>
        private protected override void ButtonRight_Click(object? sender, RoutedEventArgs e)
        {
            // Only set DialogResult if it hasn't been set by a derived class (still has default "Timeout" value).
            if (CustomDialogResult.DefaultResult.Equals(DialogResult))
            {
                DialogResult = new CustomDialogResult(((AccessText)ButtonRight.Content).Text.Replace("_", newValue: null, StringComparison.Ordinal));
            }
            base.ButtonRight_Click(sender, e);
        }
    }
}
