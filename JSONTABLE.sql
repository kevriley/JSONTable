/*----------------------------------------------------------------------------- 
  Date		: 14 January 2021
  Author	: Kevan Riley 
  Email		: info@rileywaterhouse.co.uk 
  Source	: https://github.com/kevriley/JSONTable
  Website	: https://rileywaterhouse.co.uk

  Summary: 
  This script returns a tabular representation of a JSON document
  ===========================================================================
  Modification History:
	Kevan Riley - 14 January 2021 - Created
  ===========================================================================
  Notes:
  Inspired by XMLTABLE() by Jacob Sebastian, previously at http://beyondrelational.com/blogs/jacob / http://beyondrelational.com / https://gist.github.com/jacobvettickal/601c197d716d0aeb40c1c177ca1503d8
  Some of these links are now dead and I can't find the correct attribution URL


  If you find this script useful, let us know by writing a comment at
  https://rileywaterhouse.co.uk/jsontable
  ===========================================================================	
	MIT License

	Copyright (c) 2022 Kevan Riley

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
-----------------------------------------------------------------------------*/ 
/* 
SELECT * FROM dbo.JSONTable(' 
{
    "glossary": {
        "title": "example glossary",
		"GlossDiv": {
            "title": "S",
			"GlossList": {
                "GlossEntry": {
                    "ID": "SGML",
					"SortAs": "SGML",
					"GlossTerm": "Standard Generalized Markup Language",
					"Acronym": "SGML",
					"Abbrev": "ISO 8879:1986",
					"GlossDef": {
                        "para": "A meta-markup language, used to create markup languages such as DocBook.",
						"GlossSeeAlso": ["GML", "XML"]
                    },
					"GlossSee": "markup"
                }
            }
        }
    }
}
') 
*/ 

CREATE function dbo.JSONTable( 
    @jsondoc nvarchar(max) 
) 
returns table 
as return 

with json_cte as (

    select 
        1 as lvl, 
        cast([Key] as nvarchar(max)) collate database_default as Name, 
        cast(null as nvarchar(max)) as ParentName,
        --cast(1 as int) as ParentPosition,
		case Type 
			when 0 then 'null'
			when 1 then 'string'
			when 2 then 'number'
			when 3 then 'true/false'
			when 4 then 'array'
			when 5 then 'object'
		end as NodeType,
        cast([Key] as nvarchar(max)) as FullPath, 
		cast(N'$.'+[Key] as nvarchar(max)) as JSONPath,
        --row_number() over(order by (select 1)) as Position,
		cast([Key] as nvarchar(max)) collate database_default as Tree, 
		cast(json_value(@jsondoc, N'$.'+quotename([Key],'"')) as nvarchar(max)) as Value,
		cast(json_query(@jsondoc, N'$') as nvarchar(max)) collate database_default as this,        
		cast(json_query(@jsondoc, N'$.'+quotename([Key],'"')) as nvarchar(max)) as t,        
		cast(cast(1 as varbinary(4)) as varbinary(max)) as Sort, 
		cast(1 as int) as ID 
    from openjson(@jsondoc)
union all
 
   select 
		json_cte.lvl + 1 as lvl, 
        cast(nextlevel.[Key] as nvarchar(max)) collate database_default as Name, 
        cast(json_cte.Name as nvarchar(max)) as ParentName,
        --cast(json_cte.Position as int) as ParentPosition,
		case nextlevel.Type 
			when 0 then 'null'
			when 1 then 'string'
			when 2 then 'number'
			when 3 then 'true/false'
			when 4 then 'array'
			when 5 then 'object'
		end as NodeType, 
        case 
			when json_cte.NodeType = 'array' then cast(json_cte.FullPath + N'[' + nextlevel.[Key] + N']' as nvarchar(max)) 
			else cast(json_cte.FullPath + N'/' + nextlevel.[Key] as nvarchar(max)) 
		end as FullPath, 
        case
			when json_cte.NodeType = 'array' then cast(json_cte.JSONPath + N'[' + nextlevel.[Key] + N']' as nvarchar(max) )
			else cast(json_cte.JSONPath + N'.' + nextlevel.[Key]  as nvarchar(max) )
		end as JSONPath, 
        --row_number() over(
		--		partition by cast(nextlevel.[Key] as nvarchar(max))
		--		order by (select 1)) as Position,
        cast( 
            space(2 * json_cte.lvl - 1) + N'|' + replicate(N'-', 1)
            + nextlevel.[Key] as nvarchar(max) 
			) collate database_default as Tree, 
		case 
			when json_cte.NodeType = 'array' then cast(json_value(json_cte.t, N'$' + N'[' + nextlevel.[Key] + N']') as nvarchar(max))
			else cast(json_value(json_cte.t, N'$.'+quotename(nextlevel.[Key],'"')) as nvarchar(max))
		end as Value,
		cast(json_query(json_cte.t, N'$') as nvarchar(max)) collate database_default as this,
		case 
			when json_cte.NodeType = 'array' then cast(json_query(json_cte.t, N'$' + N'[' + nextlevel.[Key] + N']') as nvarchar(max))
			else cast(json_query(json_cte.t, N'$.'+quotename(nextlevel.[Key],'"')) as nvarchar(max))
		end as t,
        cast( 
            json_cte.Sort 
            + cast( (json_cte.lvl + 1) * 1024 
            + (row_number() over(order by (select 1)) * 2) as varbinary(4) 
			) as varbinary(max) ) as Sort, 
        cast( 
            (json_cte.lvl + 1) * 1024 
            + (row_number() over(order by (select 1)) * 2) as int 
			) as ID
    from json_cte
    cross apply openjson(json_cte.t) nextlevel
)

select 
    row_number() over(order by Sort, ID) as ID, 
    ParentName, lvl as Depth, Name, 
    NodeType, FullPath, JSONPath, Tree as TreeView, Value, this as JSONData
from json_cte