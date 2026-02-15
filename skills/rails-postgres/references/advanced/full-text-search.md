# Full-Text Search

PostgreSQL has built-in full-text search capabilities using tsvector and tsquery.

## Basic Full-Text Search

```ruby
class CreateDocuments < ActiveRecord::Migration[7.1]
  def change
    create_table :documents do |t|
      t.string :title
      t.text :body
      t.timestamps
    end
    
    # Index for full-text search
    add_index :documents, 
              "to_tsvector('english', title || ' ' || body)", 
              using: :gin, 
              name: "documents_search_idx"
  end
end

class Document < ApplicationRecord
end

# Usage
Document.create(title: "Cats and Dogs", body: "are nice!")

# Search matching 'cat & dog'
Document.where("to_tsvector('english', title || ' ' || body) @@ to_tsquery(?)",
               "cat & dog")
```

## Stored Tsvector Column

More efficient - compute once and store:

```ruby
class CreateDocuments < ActiveRecord::Migration[7.1]
  def change
    create_table :documents do |t|
      t.string :title
      t.text :body
      t.virtual :textsearchable_index_col,
                type: :tsvector,
                as: "to_tsvector('english', COALESCE(title, '') || ' ' || COALESCE(body, ''))",
                stored: true
      t.timestamps
    end
    
    add_index :documents, :textsearchable_index_col, using: :gin
  end
end

class Document < ApplicationRecord
end

# Search using stored tsvector
Document.where("textsearchable_index_col @@ to_tsquery(?)", "cat & dog")
```

## Query Operators

```ruby
# AND operator
Post.where("to_tsvector('english', content) @@ to_tsquery(?)", "ruby & rails")

# OR operator
Post.where("to_tsvector('english', content) @@ to_tsquery(?)", "ruby | python")

# NOT operator
Post.where("to_tsvector('english', content) @@ to_tsquery(?)", "ruby & !python")

# Phrase search
Post.where("to_tsvector('english', content) @@ to_tsquery(?)", "'ruby on rails'")
```

## Ranking Results

```ruby
# Rank by relevance
Post.select('posts.*, 
            ts_rank(to_tsvector(\'english\', content), 
                   to_tsquery(\'ruby\')) as rank')
    .where("to_tsvector('english', content) @@ to_tsquery(?)", "ruby")
    .order('rank DESC')

# ts_rank_cd for weighted ranking
Post.select('posts.*,
            ts_rank_cd(to_tsvector(\'english\', content),
                      to_tsquery(\'ruby\')) as rank')
    .where("to_tsvector('english', content) @@ to_tsquery(?)", "ruby")
    .order('rank DESC')
```

## Language-Specific Stemming

```ruby
# English stemming (default)
to_tsvector('english', 'running quickly')
# => 'quick':2 'run':1

# Other languages
to_tsvector('french', text)
to_tsvector('spanish', text)
to_tsvector('german', text)

# Dynamic language selection
query_lang = params[:language] || 'english'
Post.where("to_tsvector(?, content) @@ to_tsquery(?, ?)", 
           query_lang, 
           query_lang,
           search_term)
```

## Advanced: Weighted Search

```ruby
# Give different weights to title vs body
class CreateArticles < ActiveRecord::Migration[7.1]
  def change
    create_table :articles do |t|
      t.string :title
      t.text :body
      t.virtual :search_vector,
                type: :tsvector,
                as: "setweight(to_tsvector('english', COALESCE(title, '')), 'A') ||
                     setweight(to_tsvector('english', COALESCE(body, '')), 'D')",
                stored: true
      t.timestamps
    end
    
    add_index :articles, :search_vector, using: :gin
  end
end

class Article < ApplicationRecord
end

# Ranking respects weights (A > B > C > D)
Article.select('articles.*, ts_rank(search_vector, to_tsquery(?)) as rank')
        .where("search_vector @@ to_tsquery(?)", search_term)
        .order('rank DESC')
```

## Trigram Search (Fuzzy Matching)

For typo-tolerant search, use trigram extension:

```ruby
class CreatePosts < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'pg_trgm'
    
    create_table :posts do |t|
      t.string :title
      t.timestamps
    end
    
    # Index for trigram search
    add_index :posts, :title, using: :gin, opclass: :gin_trgm_ops
  end
end

# Find similar titles (fuzzy matching)
Post.where("title % ?", search_term)  # % is the similarity operator
```
