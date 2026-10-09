using System;
using Xunit;

[assembly: AssemblyFixture(typeof(PSADT.UserInterface.Interfaces.Tests.TestHelpers.DialogHostFixture))]

namespace PSADT.UserInterface.Interfaces.Tests.TestHelpers
{
    /// <summary>
    /// Completes shared WPF cleanup after all tests in the assembly finish, before process-exit callbacks run.
    /// </summary>
    public sealed class DialogHostFixture : IDisposable
    {
        /// <summary>
        /// Shuts down the initialized dialog host and waits for its owning thread to exit.
        /// </summary>
        public void Dispose()
        {
            DialogHost.Shutdown();
        }
    }
}
