using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;

namespace HolyCheese_Azdo_Tools.UnitTests.Common
{
    public class NullLoggerProvider : ILoggerProvider
    {
        public ILogger CreateLogger(string categoryName) => new NullLogger();
        public void Dispose() { }
    }

}
