import json
import sys

def resolve_ref(ref, spec):
    parts = ref.split('/')
    obj = spec
    for part in parts[1:]:
        obj = obj.get(part, {})
    return obj

def format_schema(schema, spec, indent=0):
    if not schema:
        return ""
    
    out = ""
    prefix = "  " * indent
    
    if '$ref' in schema:
        resolved = resolve_ref(schema['$ref'], spec)
        return format_schema(resolved, spec, indent)
        
    schema_type = schema.get('type', 'object')
    if schema_type == 'object':
        properties = schema.get('properties', {})
        required = schema.get('required', [])
        
        out += "{\n"
        for i, (prop_name, prop_details) in enumerate(properties.items()):
            req_str = "Required" if prop_name in required else "Optional"
            
            prop_type = prop_details.get('type', 'string')
            
            if '$ref' in prop_details:
                resolved = resolve_ref(prop_details['$ref'], spec)
                prop_type = resolved.get('type', 'object')
            elif prop_type == 'array':
                items = prop_details.get('items', {})
                if '$ref' in items:
                    prop_type = "array of objects"
                else:
                    prop_type = f"array of {items.get('type', 'string')}s"
            
            desc = prop_details.get('description', '')
            desc_str = f" // {req_str}: {desc}" if desc else f" // {req_str}"
            
            comma = "," if i < len(properties) - 1 else ""
            out += f"{prefix}  \"{prop_name}\": <{prop_type}>{comma}{desc_str}\n"
        out += f"{prefix}}}"
    elif schema_type == 'array':
        out += "[\n"
        items = schema.get('items', {})
        out += f"{prefix}  {format_schema(items, spec, indent + 1)}\n"
        out += f"{prefix}]"
    else:
        out += f"<{schema_type}>"
        
    return out

def get_example_request_json(schema, spec):
    return format_schema(schema, spec)

def generate_docs(openapi_path):
    with open(openapi_path, 'r', encoding='utf-8') as f:
        spec = json.load(f)

    md = []
    
    # 1. Introduction
    title = spec.get('info', {}).get('title', 'API Documentation')
    version = spec.get('info', {}).get('version', '1.0.0')
    description = spec.get('info', {}).get('description', 'Comprehensive documentation for the API.')
    
    md.append(f"# {title}")
    md.append(f"**Version:** {version}")
    md.append("**Base URL:** `/api/v1` (or relative to your environment)")
    md.append(f"\n{description}\n")
    
    md.append("---\n")
    
    # 2. Authentication
    md.append("## Authentication\n")
    md.append("Most endpoints require authentication using Bearer tokens.\n")
    md.append("### Getting a Token\n")
    md.append("Authenticate via the `/api/v1/auth/login` endpoint (or `/api/v1/auth/register` for new users).\n")
    md.append("### Using the Token\n")
    md.append("Include the token in the `Authorization` header for protected routes:\n")
    md.append("```\nAuthorization: Bearer YOUR_TOKEN\n```\n")
    
    md.append("---\n")
    
    # 3. Usage Guidelines
    md.append("## Usage Guidelines\n")
    md.append("- **Format**: All data should be sent and received as JSON unless multipart/form-data is specified (e.g. for image uploads).\n")
    md.append("- **Pagination**: Use `skip` and `limit` query parameters on list endpoints.\n")
    md.append("- **Rate Limiting**: Check response headers or body for rate limit status (e.g., `rate_limit_remaining`). Guests have lower limits than authenticated users.\n")
    
    md.append("---\n")
    
    # 4. Error Handling
    md.append("## Error Handling\n")
    md.append("The API returns standard HTTP status codes:\n")
    md.append("- `200 OK`: Successful request")
    md.append("- `201 Created`: Resource created successfully")
    md.append("- `400 Bad Request`: Invalid input or missing parameters")
    md.append("- `401 Unauthorized`: Missing or invalid authentication token")
    md.append("- `403 Forbidden`: Authenticated but insufficient permissions")
    md.append("- `404 Not Found`: Resource not found")
    md.append("- `422 Unprocessable Entity`: Validation error in request body or parameters")
    md.append("- `429 Too Many Requests`: Rate limit exceeded")
    md.append("- `500 Internal Server Error`: Server-side error\n")
    
    md.append("Error responses generally follow this format:\n")
    md.append("```json\n{\n  \"detail\": \"Error message description\"\n}\n```\n")

    md.append("---\n")
    
    md.append("## Endpoints\n")

    paths = spec.get('paths', {})
    
    tags_dict = {}
    for path, methods in paths.items():
        for method, details in methods.items():
            if method.lower() not in ['get', 'post', 'put', 'delete', 'patch']:
                continue
            tags = details.get('tags', ['General'])
            tag = tags[0]
            if tag not in tags_dict:
                tags_dict[tag] = []
            tags_dict[tag].append({
                'path': path,
                'method': method.upper(),
                'details': details
            })

    for tag, endpoints in tags_dict.items():
        md.append(f"### {tag.capitalize()} Endpoints\n")
        for ep in endpoints:
            details = ep['details']
            summary = details.get('summary', 'Endpoint')
            desc = details.get('description', '')
            
            md.append(f"#### {summary}\n")
            if desc:
                md.append(f"{desc}\n")
            
            md.append(f"**Endpoint:** `{ep['method']} {ep['path']}`\n")
            
            # Security (Auth)
            security = details.get('security', [])
            if security:
                md.append("**Authentication:** Required (Bearer token)\n")
            else:
                # heuristic: if 'auth' not in tags and not explicitly no auth, maybe optional or required depending
                pass
            
            # Parameters
            parameters = details.get('parameters', [])
            if parameters:
                md.append("**Parameters:**")
                for p in parameters:
                    req = "Required" if p.get('required') else "Optional"
                    md.append(f"- `{p.get('name')}` ({p.get('in')}): {req}. {p.get('description', '')}")
                md.append("")
                
            # Request Body
            request_body = details.get('requestBody', {})
            if request_body:
                md.append("**Request Body:**")
                content = request_body.get('content', {})
                for c_type, c_details in content.items():
                    schema = c_details.get('schema', {})
                    if c_type == "application/json":
                        md.append("```json")
                        md.append(format_schema(schema, spec))
                        md.append("```\n")
                    else:
                        ref = schema.get('$ref', '')
                        if ref:
                            ref_name = ref.split('/')[-1]
                            md.append(f"Schema: `{ref_name}` (Content-Type: `{c_type}`)\n")
                        else:
                            md.append(f"Content-Type: `{c_type}`\n")
                
            # Responses
            responses = details.get('responses', {})
            if responses:
                md.append("**Responses:**")
                for code, r_details in responses.items():
                    desc = r_details.get('description', '')
                    md.append(f"- `{code}`: {desc}")
                    content = r_details.get('content', {})
                    if 'application/json' in content:
                        schema = content['application/json'].get('schema', {})
                        md.append("  ```json")
                        # Format response simply
                        md.append(format_schema(schema, spec, indent=1))
                        md.append("  ```")
                md.append("")
                
            # Code Examples
            md.append("**Example Request (cURL):**")
            url = f"https://api.example.com{ep['path']}"
            curl_cmd = f"curl -X {ep['method']} {url} \\"
            if security:
                curl_cmd += "\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\"
            
            if request_body:
                content = request_body.get('content', {})
                if 'application/json' in content:
                    curl_cmd += "\n  -H \"Content-Type: application/json\" \\"
                    curl_cmd += "\n  -d '{ ... }'"
                elif 'multipart/form-data' in content:
                    curl_cmd += "\n  -H \"Content-Type: multipart/form-data\" \\"
                    curl_cmd += "\n  -F 'file=@/path/to/file.jpg'"
            
            md.append(f"```bash\n{curl_cmd}\n```\n")

    return "\n".join(md)

if __name__ == "__main__":
    openapi_file = "openapi.json"
    if len(sys.argv) > 1:
        openapi_file = sys.argv[1]
    
    try:
        md_content = generate_docs(openapi_file)
        with open("API_DOCUMENTATION_FULL.md", "w", encoding="utf-8") as f:
            f.write(md_content)
        print("Successfully generated API_DOCUMENTATION_FULL.md")
    except Exception as e:
        print(f"Error: {e}")
