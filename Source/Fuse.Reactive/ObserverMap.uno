using Uno;
using Uno.Collections;

namespace Fuse.Reactive
{
	//UNO: Cast to IArray was failing if this class is declared inside ObserverMap
	//https://github.com/fusetools/uno/issues/1321
	class UnmappedView<T> : IArray where T : class
	{
		ObserverMap<T> _source;
		public UnmappedView( ObserverMap<T> source )
		{
			_source = source;
		}
		
		public int Length { get { return _source._list.Count; } } 
		public object this[int index] { get { return _source.UVUnmap(_source._list[index]); } }
	}
	
	/**
		A two-way mapped observable list. This serves as the outermost list: the list functions here will update the backing Observable.
	*/
	abstract class ObserverMap<T> : IObserver where T : class
	{
		internal List<T> _list = new List<T>();
		
		protected abstract T Map(object v);
		protected abstract object Unmap(T mv);
		protected virtual void OnUpdated() { }
	
		internal object UVUnmap(T mv) { return Unmap(mv); }
		
		public int Count { get { return _list.Count; } }
		public T this[int index]
		{
			get { return _list[index]; }
			set { _list[index] = value; }
		}
			
		
		IArray _source;
		IObservable _observable;
		IObserver _slave;
		ISubscription _subscription;
		
		/**
			@param obs The observable to attach to
			@param slace An optional slave observer that will also receive callbacks from the observable. 
				This allows that slave to behave as a part of this map, rather than subscribing and getting
				copies of the events. This is important especially when this map updates the observable,
				we don't want the slave getting events for that.
		*/
		public void Attach( IArray src, IObserver slave = null ) 
		{
			Detach();
			_source = src;
			_observable = src as IObservable;
			
			if (_observable != null)
				_subscription = _observable.Subscribe(this);
				
			//treat the bound observable as the source-of-truth
			((IObserver)this).OnNewAll(src);
			
			//set after call to OnNewAll since Attach should not generate a callback
			_slave = slave;	
		}
		
		public void Detach()
		{
			if (_subscription != null)
			{
				_subscription.Dispose();
				_subscription = null;
			}
			_observable = null;
			_source = null;
			_slave = null;
		}
		
		public void Add( T value )
		{
			_list.Add(value);
			UpdateBacking();
		}
		
		public void RemoveAt( int index )
		{
			_list.RemoveAt(index);
			UpdateBacking();
		}
		
		public void Insert( int index, T value )
		{
			_list.Insert(index, value);
			UpdateBacking();
		}
		
		public void Clear()
		{
			_list.Clear();
			UpdateBacking();
		}
		
		void UpdateBacking()
		{
			if (_subscription == null)
				return;
	
			IArray uv = 	new UnmappedView<T>(this);
			_subscription.ReplaceAllExclusive( uv );	
		}
		
		void IObserver.OnClear()
		{
			_list.Clear();
			OnUpdated();
			
			if (_slave != null)
				_slave.OnClear();
		}
		
		void IObserver.OnNewAll(IArray values)
		{
			_list.Clear();
			for (int i=0; i < values.Length;  ++i)
				_list.Add( Map(values[i]) );
			OnUpdated();
			
			if (_slave != null)
				_slave.OnNewAll(values);
		}
		
		void IObserver.OnNewAt(int index, object newValue)
		{
			_list[index] = Map(newValue);
			OnUpdated();
			
			if (_slave != null)
				_slave.OnNewAt(index, newValue);
		}
		
		void IObserver.OnSet(object newValue)
		{
			_list.Clear();
			_list.Add( Map(newValue) );
			OnUpdated();
			
			if (_slave != null)
				_slave.OnSet(newValue);
		}
		
		void IObserver.OnAdd(object addedValue)
		{
			_list.Add( Map(addedValue) );
			OnUpdated();
			
			if (_slave != null)
				_slave.OnAdd(addedValue);
		}
		
		void IObserver.OnRemoveAt(int index)
		{
			_list.RemoveAt(index);
			OnUpdated();
			
			if (_slave != null)
				_slave.OnRemoveAt(index);
		}
		
		void IObserver.OnInsertAt(int index, object value)
		{
			_list.Insert(index, Map(value));
			OnUpdated();
			
			if (_slave != null)
				_slave.OnInsertAt(index, value);
		}
		
		void IObserver.OnFailed(string message)
		{
			_list.Clear();
			OnUpdated();
			
			if (_slave != null)
				_slave.OnFailed(message);
		}
	}
}
	