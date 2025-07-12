using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;

namespace HolyCheeseAzdoTools.UnitTests.Common
{
    public class NullLoggerProvider : ILoggerProvider
    {
        public ILogger CreateLogger(string categoryName) => new NullLogger();
        public void Dispose() { }
    }

}
