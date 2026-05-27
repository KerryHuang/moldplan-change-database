using System.Net;

namespace MoldplanDbSwitcher.Tests.TestHelpers;

public class FakeHttpMessageHandler : HttpMessageHandler
{
    private readonly Func<HttpRequestMessage, HttpResponseMessage> _responder;
    public List<HttpRequestMessage> Requests { get; } = new();

    public FakeHttpMessageHandler(Func<HttpRequestMessage, HttpResponseMessage> responder)
    {
        _responder = responder;
    }

    public static FakeHttpMessageHandler Json(HttpStatusCode status, string json) =>
        new(_ => new HttpResponseMessage(status)
        {
            Content = new StringContent(json, System.Text.Encoding.UTF8, "application/json")
        });

    public static FakeHttpMessageHandler Throws(Exception ex) =>
        new(_ => throw ex);

    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        Requests.Add(request);
        return Task.FromResult(_responder(request));
    }
}
