using System;
using System.Linq;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using PSADT.UserInterface.DialogOptions;
using PSADT.UserInterface.DialogResults;

namespace PSADT.UserInterface.Interfaces.Fluent
{
    /// <summary>
    /// A fluent implementation of PSAppDeployToolkit's List Selection dialog.
    /// </summary>
    internal sealed class ListSelectionDialog : CustomDialog, IModalDialog
    {
        /// <summary>
        /// Initializes the UI elements and behavior for the List Selection dialog type.
        /// </summary>
        /// <param name="options">Mandatory options needed to construct the window.</param>
        internal ListSelectionDialog(ListSelectionDialogOptions options) : base(options, ListSelectionDialogResult.DefaultResult)
        {
            // Enable the ListSelectionStackPanel within the dialog
            ListSelectionStackPanel.Visibility = Visibility.Visible;

            // Set up UI
            SetDefaultButton(ButtonLeft);
            SetAccentButton(ButtonLeft);
            SetCancelButton(ButtonRight);

            // Populate and show the List Selection ComboBox.
            foreach (string item in options.ListItems)
            {
                _ = ListSelectionComboBox.Items.Add(item);
            }

            // Disable all except the cancel button until an item is selected.
            if (!options.SelectedIndex.HasValue)
            {
                ListSelectionComboBox.SelectionChanged += (sender, e) =>
                {
                    ButtonLeft.IsEnabled = ListSelectionComboBox.SelectedIndex >= 0;
                    ButtonMiddle.IsEnabled = ListSelectionComboBox.SelectedIndex >= 0;
                };
                ButtonLeft.IsEnabled = false;
                ButtonMiddle.IsEnabled = false;
            }
            else
            {
                ListSelectionComboBox.SelectedIndex = options.SelectedIndex.Value;
            }
            // Set heading text from localized strings if available.
            ListSelectionHeadingTextBlock.Text = options.Strings.ListSelectionMessage;
            _buttonDisabledFormat = options.Strings.ButtonDisabledFormat;

            // Associate the combo box with its visible heading so a screen reader announces the heading
            // as the control's label.
            AutomationProperties.SetLabeledBy(ListSelectionComboBox, ListSelectionHeadingTextBlock);
        }

        /// <inheritdoc />
        private protected override FrameworkElement? GetInitialFocusElement()
        {
            return ListSelectionComboBox;
        }

        /// <inheritdoc />
        private protected override string? GetOpenAnnouncement()
        {
            // App name + message + custom (base prefix), then the list heading and items, then each button
            // per the button rule (SR7). SR9: nothing else is read.
            string? heading = ListSelectionHeadingTextBlock.Visibility == Visibility.Visible ? GetPlainText(ListSelectionHeadingTextBlock) : null;
            string? items = ListSelectionComboBox.Items.Count > 0
                ? string.Join(", ", ListSelectionComboBox.Items.Cast<object>().Select(static i => i?.ToString()))
                : null;
            return JoinAnnouncement(
                GetBaseOpenAnnouncement(),
                heading,
                items,
                GetButtonAnnouncement(ButtonLeft, _buttonDisabledFormat),
                GetButtonAnnouncement(ButtonMiddle, _buttonDisabledFormat),
                GetButtonAnnouncement(ButtonRight, _buttonDisabledFormat));
        }

        /// <summary>
        /// The localized "{0} has been disabled" format used when reading a visible but disabled button (SR7).
        /// </summary>
        private readonly string _buttonDisabledFormat;

        /// <summary>
        /// Handles the click event for the left button, setting the dialog result based on the selected item and the
        /// button's content.
        /// </summary>
        /// <param name="sender">The source of the event, typically the button that was clicked.</param>
        /// <param name="e">The event data associated with the click event.</param>
        private protected override void ButtonLeft_Click(object? sender, RoutedEventArgs e)
        {
            // Set the result and call base method to handle window closure.
            DialogResult = new ListSelectionDialogResult(((AccessText)ButtonLeft.Content).Text.Replace(oldValue: "_", newValue: null, StringComparison.OrdinalIgnoreCase), (string)ListSelectionComboBox.SelectedItem);
            base.ButtonLeft_Click(sender, e);
        }

        /// <summary>
        /// Handles the click event for the middle button, setting the dialog result based on the selected item and the
        /// button's content.
        /// </summary>
        /// <param name="sender">The source of the event, typically the button that was clicked.</param>
        /// <param name="e">The event data associated with the click event.</param>
        private protected override void ButtonMiddle_Click(object? sender, RoutedEventArgs e)
        {
            // Set the result and call base method to handle window closure.
            DialogResult = new ListSelectionDialogResult(((AccessText)ButtonMiddle.Content).Text.Replace(oldValue: "_", newValue: null, StringComparison.OrdinalIgnoreCase), (string)ListSelectionComboBox.SelectedItem);
            base.ButtonMiddle_Click(sender, e);
        }

        /// <summary>
        /// Handles the click event for the right button, setting the dialog result based on the selected item and the
        /// button's content.
        /// </summary>
        /// <param name="sender">The source of the event, typically the button that was clicked.</param>
        /// <param name="e">The event data associated with the click event.</param>
        private protected override void ButtonRight_Click(object? sender, RoutedEventArgs e)
        {
            // Set the result and call base method to handle window closure.
            DialogResult = new ListSelectionDialogResult(((AccessText)ButtonRight.Content).Text.Replace(oldValue: "_", newValue: null, StringComparison.OrdinalIgnoreCase), (string)ListSelectionComboBox.SelectedItem);
            base.ButtonRight_Click(sender, e);
        }
    }
}
