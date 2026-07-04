using System;
using System.ComponentModel;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using PSADT.UserInterface.DialogOptions;
using PSADT.UserInterface.DialogResults;

namespace PSADT.UserInterface.Interfaces.Fluent
{
    /// <summary>
    /// A fluent implementation of PSAppDeployToolkit's Input dialog.
    /// </summary>
    internal sealed class InputDialog : CustomDialog, IModalDialog
    {
        /// <summary>
        /// Initializes the UI elements and behavior for the Input dialog type.
        /// </summary>
        /// <param name="options">Mandatory options needed to construct the window.</param>
        internal InputDialog(InputDialogOptions options) : base(options, InputDialogResult.DefaultResult)
        {
            // Enable input box within the dialog
            InputBoxStackPanel.Visibility = Visibility.Visible;
            SetDefaultButton(ButtonLeft);
            SetAccentButton(ButtonLeft);
            SetCancelButton(ButtonRight);

            // Configure based on secure input mode.
            if (_secureInput = options.SecureInput)
            {
                InputBoxText.Visibility = Visibility.Collapsed;
                InputBoxPassword.Visibility = Visibility.Visible;
                DependencyPropertyDescriptor.FromProperty(Fluence.Wpf.Controls.PasswordBox.PasswordProperty, typeof(Fluence.Wpf.Controls.PasswordBox))?.AddValueChanged(InputBoxPassword, OnInputChanged);
                Loaded += static (sender, __) =>
                {
                    if (sender is not InputDialog dialog)
                    {
                        throw new InvalidProgramException("Unexpected Loaded event sender type. Expected InputDialog.");
                    }
                    dialog.InputBoxPassword.SelectAll();
                };
            }
            else
            {
                InputBoxText.Text = options.InitialInputText;
                InputBoxText.TextChanged += OnTextInputChanged;
                Loaded += static (sender, __) =>
                {
                    if (sender is not InputDialog dialog)
                    {
                        throw new InvalidProgramException("Unexpected Loaded event sender type. Expected InputDialog.");
                    }
                    dialog.InputBoxText.SelectAll();
                };
            }
            UpdateContinueButtonState();

            // Associate the input field with the visible prompt so a screen reader announces the question
            // as the field's label. (For secure input this targets the outer wrapper; the inner password
            // field announces as a protected field — see residual limitations.)
            AutomationProperties.SetLabeledBy(InputBoxText, MessageTextBlock);
            AutomationProperties.SetLabeledBy(InputBoxPassword, MessageTextBlock);
        }

        /// <inheritdoc />
        private protected override System.Windows.FrameworkElement? GetInitialFocusElement()
        {
            return _secureInput ? InputBoxPassword : InputBoxText;
        }

        /// <summary>
        /// Updates the continue button's enabled state when the text input changes.
        /// </summary>
        /// <param name="sender">The source of the event, typically the input control that was modified.</param>
        /// <param name="e">The event data associated with the text change event.</param>
        private void OnTextInputChanged(object sender, TextChangedEventArgs e)
        {
            UpdateContinueButtonState();
        }

        /// <summary>
        /// Updates the continue button's enabled state when the password input changes.
        /// </summary>
        /// <param name="sender">The source of the event, typically the input control that was modified.</param>
        /// <param name="e">The event data associated with the input change event.</param>
        private void OnInputChanged(object? sender, EventArgs e)
        {
            UpdateContinueButtonState();
        }

        /// <summary>
        /// Enables or disables the continue button based on whether the current input value is null, empty, or consists solely of whitespace.
        /// </summary>
        private void UpdateContinueButtonState()
        {
            ButtonLeft.IsEnabled = !string.IsNullOrWhiteSpace(CurrentInputValue);
        }

        /// <summary>
        /// Handles the click event for the left button, setting the dialog result based on the button's content and the
        /// current input value.
        /// </summary>
        /// <param name="sender">The source of the event, typically the button that was clicked.</param>
        /// <param name="e">The event data associated with the click event.</param>
        private protected override void ButtonLeft_Click(object? sender, RoutedEventArgs e)
        {
            // Set the result and call base method to handle window closure.
            DialogResult = new InputDialogResult(((AccessText)ButtonLeft.Content).Text.Replace(oldValue: "_", newValue: null, StringComparison.OrdinalIgnoreCase), CurrentInputValue);
            base.ButtonLeft_Click(sender, e);
        }

        /// <summary>
        /// Handles the click event for the middle button, setting the dialog result based on the button's content and
        /// the current input value.
        /// </summary>
        /// <param name="sender">The source of the event, typically the button that was clicked.</param>
        /// <param name="e">The event data associated with the click event.</param>
        private protected override void ButtonMiddle_Click(object? sender, RoutedEventArgs e)
        {
            // Set the result and call base method to handle window closure.
            DialogResult = new InputDialogResult(((AccessText)ButtonMiddle.Content).Text.Replace(oldValue: "_", newValue: null, StringComparison.OrdinalIgnoreCase), CurrentInputValue);
            base.ButtonMiddle_Click(sender, e);
        }

        /// <summary>
        /// Handles the click event for the right button in the input dialog, setting the dialog result based on the
        /// button's content and the current input value.
        /// </summary>
        /// <param name="sender">The source of the event, typically the right button that was clicked.</param>
        /// <param name="e">The event data associated with the button click.</param>
        private protected override void ButtonRight_Click(object? sender, RoutedEventArgs e)
        {
            // Set the result and call base method to handle window closure.
            DialogResult = new InputDialogResult(((AccessText)ButtonRight.Content).Text.Replace(oldValue: "_", newValue: null, StringComparison.OrdinalIgnoreCase), CurrentInputValue);
            base.ButtonRight_Click(sender, e);
        }

        /// <summary>
        /// Gets the current input value from either the TextBox or PasswordBox.
        /// </summary>
        private string? CurrentInputValue => _secureInput ? InputBoxPassword.Password : InputBoxText.Text;

        /// <summary>
        /// Indicates whether the input box is in secure input mode.
        /// </summary>
        private readonly bool _secureInput;
    }
}
