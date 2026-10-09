using System;
using System.Collections;
using System.Windows;
using System.Windows.Media;
using Fluence.Wpf;
using PSADT.UserInterface.DialogOptions;
using PSADT.UserInterface.Interfaces.Fluent;
using PSADT.UserInterface.Interfaces.Tests.TestHelpers;
using Xunit;

namespace PSADT.UserInterface.Interfaces.Tests.Fluent
{
    /// <summary>
    /// Tests the dialog's calculated and exact accent dispatch across theme changes.
    /// </summary>
    public sealed class FluentAccentColorTests
    {
        private static readonly Color LightAccent = Color.FromRgb(0x87, 0xAB, 0xC8);
        private static readonly Color DarkAccent = Color.FromRgb(0x42, 0x36, 0xA4);

        /// <summary>
        /// Verifies that two exact colors stay visible through repeated theme switches.
        /// </summary>
        [Fact]
        public void ExactPair_PinsBothVisibleFillsAcrossThemeSwitches()
        {
            WithAccentDialog(Options(light: LightAccent, dark: DarkAccent, exact: true), static dialog =>
            {
                ApplyTheme(ApplicationTheme.Light);
                Assert.Equal(LightAccent, VisibleFill(dialog));
                Assert.Equal(LightAccent, ApplicationAccentColorManager.SystemAccentColor);
                Assert.Equal(LightAccent, ApplicationAccentColorManager.SystemAccentColorPrimary);

                ApplyTheme(ApplicationTheme.Dark);
                Assert.Equal(DarkAccent, VisibleFill(dialog));
                Assert.Equal(DarkAccent, ApplicationAccentColorManager.SystemAccentColor);
                Assert.Equal(DarkAccent, ApplicationAccentColorManager.SystemAccentColorPrimary);

                ApplyTheme(ApplicationTheme.HighContrast);
                Assert.Equal(SystemColors.WindowColor, Assert.IsType<SolidColorBrush>(dialog.TryFindResource("AccentFillColorDefaultBrush")).Color);
                Assert.Equal(SystemColors.HighlightColor, Assert.IsType<SolidColorBrush>(dialog.TryFindResource("SystemAccentColorPrimaryBrush")).Color);

                ApplyTheme(ApplicationTheme.Light);
                Assert.Equal(LightAccent, VisibleFill(dialog));
                Assert.Equal(LightAccent, ApplicationAccentColorManager.SystemAccentColor);
            });
        }

        /// <summary>
        /// Verifies that a single exact Light color derives the Dark primary from its ramp.
        /// </summary>
        [Fact]
        public void ExactLightOnly_DerivesDarkVisibleFillFromResolvedRamp()
        {
            WithAccentDialog(Options(light: LightAccent, dark: null, exact: true), static dialog =>
            {
                ApplyTheme(ApplicationTheme.Light);
                Assert.Equal(LightAccent, VisibleFill(dialog));
                Assert.Equal(LightAccent, ApplicationAccentColorManager.SystemAccentColor);

                ApplyTheme(ApplicationTheme.Dark);
                Assert.Equal(ApplicationAccentColorManager.SystemAccentColorLight2, VisibleFill(dialog));
                Assert.NotEqual(LightAccent, VisibleFill(dialog));
            });
        }

        /// <summary>
        /// Verifies that a calculated Light seed remains pinned while Dark uses its derived shade.
        /// </summary>
        [Fact]
        public void CalculatedLightOnly_DerivesDarkVisibleFillAcrossThemeSwitches()
        {
            WithAccentDialog(Options(light: LightAccent, dark: null, exact: null), static dialog =>
            {
                ApplyTheme(ApplicationTheme.Dark);
                Assert.Equal(ApplicationAccentColorManager.SystemAccentColorLight2, VisibleFill(dialog));

                ApplyTheme(ApplicationTheme.Light);
                Assert.Equal(LightAccent, ApplicationAccentColorManager.SystemAccentColor);
                Assert.Equal(ApplicationAccentColorManager.SystemAccentColorDark1, VisibleFill(dialog));
                Assert.NotEqual(LightAccent, VisibleFill(dialog));

                ApplyTheme(ApplicationTheme.Dark);
                Assert.Equal(ApplicationAccentColorManager.SystemAccentColorLight2, VisibleFill(dialog));
            });
        }

        /// <summary>
        /// Verifies that a Dark-only override leaves Light on the Windows accent.
        /// </summary>
        [Fact]
        public void ExactDarkOnly_UsesSystemLightAndExplicitDark()
        {
            Color systemLight = SystemFill(ApplicationTheme.Light);
            WithAccentDialog(Options(light: null, dark: DarkAccent, exact: true), dialog =>
            {
                ApplyTheme(ApplicationTheme.Light);
                Assert.Equal(systemLight, VisibleFill(dialog));

                ApplyTheme(ApplicationTheme.Dark);
                Assert.Equal(DarkAccent, VisibleFill(dialog));
                Assert.Equal(DarkAccent, ApplicationAccentColorManager.SystemAccentColor);

                ApplyTheme(ApplicationTheme.Light);
                Assert.Equal(systemLight, VisibleFill(dialog));
            });
        }

        /// <summary>
        /// Verifies that a calculated Dark-only seed leaves Light on Windows and uses its Dark shade.
        /// </summary>
        [Fact]
        public void CalculatedDarkOnly_UsesSystemLightAndDerivedDark()
        {
            Color systemLight = SystemFill(ApplicationTheme.Light);
            WithAccentDialog(Options(light: null, dark: DarkAccent, exact: null), dialog =>
            {
                ApplyTheme(ApplicationTheme.Light);
                Assert.Equal(systemLight, VisibleFill(dialog));

                ApplyTheme(ApplicationTheme.Dark);
                Assert.Equal(ApplicationAccentColorManager.SystemAccentColorLight2, VisibleFill(dialog));
                Assert.NotEqual(DarkAccent, VisibleFill(dialog));

                ApplyTheme(ApplicationTheme.Light);
                Assert.Equal(systemLight, VisibleFill(dialog));
            });
        }

        /// <summary>
        /// Verifies that omitted and false exact settings derive shades from each theme's configured seed.
        /// </summary>
        /// <param name="exact">The omitted or false exact accent setting.</param>
        [Theory]
        [InlineData(null)]
        [InlineData(false)]
        public void CalculatedPair_PreservesPerThemeSeeds(bool? exact)
        {
            WithAccentDialog(Options(light: LightAccent, dark: DarkAccent, exact), static dialog =>
            {
                ApplyTheme(ApplicationTheme.Light);
                Assert.Equal(LightAccent, ApplicationAccentColorManager.SystemAccentColor);
                Assert.Equal(ApplicationAccentColorManager.SystemAccentColorDark1, VisibleFill(dialog));
                Assert.NotEqual(LightAccent, VisibleFill(dialog));

                ApplyTheme(ApplicationTheme.Dark);
                Assert.Equal(DarkAccent, ApplicationAccentColorManager.SystemAccentColor);
                Assert.Equal(ApplicationAccentColorManager.SystemAccentColorLight2, VisibleFill(dialog));
                Assert.NotEqual(DarkAccent, VisibleFill(dialog));

                ApplyTheme(ApplicationTheme.Light);
                Assert.Equal(LightAccent, ApplicationAccentColorManager.SystemAccentColor);
                Assert.Equal(ApplicationAccentColorManager.SystemAccentColorDark1, VisibleFill(dialog));
            });
        }

        /// <summary>
        /// Verifies that a dialog without colors clears custom intent regardless of the exact setting.
        /// </summary>
        /// <param name="exact">The optional exact accent setting.</param>
        [Theory]
        [InlineData(null)]
        [InlineData(false)]
        [InlineData(true)]
        public void NoColors_ResetSystemAccentAcrossThemeSwitches(bool? exact)
        {
            Color systemLight = SystemFill(ApplicationTheme.Light);
            Color systemDark = SystemFill(ApplicationTheme.Dark);
            SeedStickyCustomAccent();
            WithAccentDialog(Options(light: null, dark: null, exact), dialog =>
            {
                ApplyTheme(ApplicationTheme.Light);
                Assert.Equal(systemLight, VisibleFill(dialog));

                ApplyTheme(ApplicationTheme.Dark);
                Assert.Equal(systemDark, VisibleFill(dialog));

                ApplyTheme(ApplicationTheme.Light);
                Assert.Equal(systemLight, VisibleFill(dialog));
            });
        }

        private static Hashtable Options(Color? light, Color? dark, bool? exact)
        {
            Hashtable options = SampleOptions.CustomDialog();
            if (light is Color lightColor)
            {
                options["FluentAccentColor"] = PackedColor(lightColor);
            }
            if (dark is Color darkColor)
            {
                options["FluentAccentColorDark"] = PackedColor(darkColor);
            }
            if (exact is bool useExactColors)
            {
                options["FluentAccentColorExact"] = useExactColors;
            }
            return options;
        }

        private static int PackedColor(Color color)
        {
            return unchecked((int)(((uint)color.A << 24) | ((uint)color.R << 16) | ((uint)color.G << 8) | color.B));
        }

        private static void ApplyTheme(ApplicationTheme theme)
        {
            ApplicationThemeManager.Apply(theme);
        }

        private static Color VisibleFill(CustomDialog dialog)
        {
            Color fill = Assert.IsType<Color>(dialog.TryFindResource("AccentFillColorDefault"));
            Assert.Equal(fill, Assert.IsType<SolidColorBrush>(dialog.TryFindResource("AccentFillColorDefaultBrush")).Color);
            return fill;
        }

        private static Color SystemFill(ApplicationTheme theme)
        {
            return DialogHost.Run(() =>
            {
                ApplicationThemeManager.Apply(theme);
                ApplicationAccentColorManager.ApplySystemAccent();
                return ApplicationAccentColorManager.SystemAccentColorPrimary;
            });
        }

        private static void SeedStickyCustomAccent()
        {
            DialogHost.Run(static () =>
            {
                ApplicationThemeManager.Apply(ApplicationTheme.Light);
                ApplicationAccentColorManager.ApplyCustomAccentExact(LightAccent, DarkAccent);
            });
        }

        private static void WithAccentDialog(Hashtable options, Action<CustomDialog> body)
        {
            DialogHost.Run(() =>
            {
                try
                {
                    using CustomDialog dialog = new(new CustomDialogOptions(options));
                    try
                    {
                        body(dialog);
                    }
                    finally
                    {
                        // Dispose detaches PSADT handlers; Close also removes the WPF window from the application.
                        dialog.CloseDialog();
                    }
                }
                finally
                {
                    ApplicationAccentColorManager.ApplySystemAccent();
                    ApplicationThemeManager.Apply(ApplicationTheme.Auto);
                }
            });
            DialogHost.Drain();
        }
    }
}
