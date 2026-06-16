using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.ViewModels.Documents;
using Xunit;

namespace MoldplanDbSwitcher.Tests.ViewModels;

public class DocumentViewModelTests
{
    private sealed class FakeDoc : DocumentViewModel
    {
        public override string DocumentType => "Fake";
    }

    [Fact]
    public void DocumentKey_Defaults_ToDocumentType()
    {
        var doc = new FakeDoc();
        Assert.Equal("Fake", doc.DocumentKey);
    }

    [Fact]
    public void CanClose_DefaultsTrue()
    {
        Assert.True(new FakeDoc().CanClose);
    }

    [Fact]
    public void CloseCommand_RaisesCloseRequested_WithSelf()
    {
        var doc = new FakeDoc();
        DocumentViewModel? raised = null;
        doc.CloseRequested += d => raised = d;
        doc.CloseCommand.Execute(null);
        Assert.Same(doc, raised);
    }

    [Fact]
    public async Task UseConnectionAsync_DefaultNoOp_DoesNotThrow()
    {
        var doc = new FakeDoc();
        await doc.UseConnectionAsync(new ActiveConnection("cs", "db", null));
    }
}
