/*
 * Copyright 2026 Dan Cunningham
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 * 3. Neither the name of the copyright holder nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

using Fluence.Wpf.Native;

namespace Fluence.Wpf.Helpers
{
    internal sealed class WindowCapabilities(
        bool supportsSystemBackdropType,
        bool supportsMicaEffect,
        bool supportsRoundedCorners,
        bool supportsCaptionColor,
        bool supportsBorderColor = false,
        bool backdropCompositionAvailable = true)
    {
        internal bool SupportsSystemBackdropType { get; private set; } = supportsSystemBackdropType;

        internal bool SupportsMicaEffect { get; private set; } = supportsMicaEffect;

        internal bool SupportsRoundedCorners { get; private set; } = supportsRoundedCorners;

        internal bool SupportsCaptionColor { get; private set; } = supportsCaptionColor;

        internal bool SupportsBorderColor { get; private set; } = supportsBorderColor;

        /// <summary>
        /// Runtime gate, distinct from the OS-version capabilities above: whether DWM will actually
        /// composite a system backdrop right now. A Mica or Acrylic window is transparent and relies
        /// on DWM painting the backdrop behind it. When DWM composition is disabled or the user's
        /// "Transparency effects" setting is off, the transparent client has nothing behind it and
        /// flashes the uncomposited surface on first paint, and stays see-through while transparency is
        /// off. In those cases the backdrop must resolve to None with an opaque background instead. See
        /// <c>WindowPolicy.ResolveEffectiveBackdrop</c>.
        /// <para>
        /// Note: WPF's <c>RenderOptions.ProcessRenderMode</c> (which selects software or hardware
        /// rasterization of WPF content) is deliberately NOT included in this gate. DWM desktop
        /// composition is a separate kernel-mode subsystem; it composites Mica and Acrylic behind a
        /// transparent window independently of how WPF rasterizes its content. A window that forces
        /// WPF software rendering still receives a real DWM Mica backdrop on a composition-capable
        /// desktop with transparency enabled.
        /// </para>
        /// </summary>
        internal bool BackdropCompositionAvailable { get; private set; } = backdropCompositionAvailable;

        internal static WindowCapabilities Current => new(
            OsVersionHelper.SupportsSystemBackdropType,
            OsVersionHelper.SupportsMicaEffect,
            OsVersionHelper.SupportsRoundedCorners,
            OsVersionHelper.SupportsCaptionColor,
            OsVersionHelper.SupportsBorderColor,
            IsBackdropCompositionAvailable());

        /// <summary>
        /// Determines whether DWM will composite a system backdrop in the current session.
        /// Gated on DWM composition being enabled and the user's "Transparency effects" setting being
        /// on. DWM desktop composition is independent of WPF's render mode: even when WPF is forced to
        /// software rasterization (<c>RenderOptions.ProcessRenderMode = SoftwareOnly</c>), DWM
        /// composites Mica and Acrylic behind a transparent window as long as these two conditions
        /// hold. When either is false a transparent backdrop window would flicker; the opaque fallback
        /// is used instead.
        /// </summary>
        private static bool IsBackdropCompositionAvailable()
        {
            return NativeMethods.IsCompositionEnabled()
                && RegistryHelper.IsTransparencyEnabled();
        }
    }
}
