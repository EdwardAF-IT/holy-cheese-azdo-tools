namespace HolyCheese_Azdo_Tools.UnitTests.TagTools
{
    public static class TagPayloads
    {
        /// <summary>
        /// Simulates a valid tag field with multiple tags.
        /// </summary>
        public static string ValidTags => "{ \"fields\": { \"System.Tags\": \"critical;urgent\" } }";

        /// <summary>
        /// Simulates a work item without System.Tags.
        /// </summary>
        public static string MissingTagsField => "{ \"fields\": { \"System.Title\": \"Missing tags\" } }";

        /// <summary>
        /// Simulates a malformed JSON structure.
        /// </summary>
        public static string MalformedJson => "{ \"fields\": { \"System.Tags\": "; // Incomplete JSON

        /// <summary>
        /// Simulates null fields inside a work item.
        /// </summary>
        public static string NullFields => "{ \"fields\": null }";

        /// <summary>
        /// Simulates a large tag string with 100 tags separated by semicolons.
        /// </summary>
        public static string LargeTagString => $"\"System.Tags\": \"{string.Join(";", Enumerable.Range(1, 100).Select(i => $"tag{i}"))}\"";

        /// <summary>
        /// Wraps a JSON snippet in a basic Azure DevOps response structure.
        /// </summary>
        public static string WrapFields(string fieldsContent) => $"{{ \"fields\": {{ {fieldsContent} }} }}";
    }
}
